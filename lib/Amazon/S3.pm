package Amazon::S3;
use strict;
use warnings;

use Carp;
use Digest::HMAC_SHA1;
use HTTP::Date;
use MIME::Base64 qw(encode_base64);
use Amazon::S3::Bucket;
use LWP::UserAgent::Determined;
use URI::Escape qw(uri_escape_utf8);
use XML::Simple;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(aws_access_key_id aws_secret_access_key secure ua err errstr timeout retry host)
);
our $VERSION = '0.45';

my $AMAZON_HEADER_PREFIX = 'x-amz-';
my $METADATA_PREFIX      = 'x-amz-meta-';
my $KEEP_ALIVE_CACHESIZE = 10;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    die "No aws_access_key_id"     unless $self->aws_access_key_id;
    die "No aws_secret_access_key" unless $self->aws_secret_access_key;

    $self->secure(0)                if not defined $self->secure;
    $self->timeout(30)              if not defined $self->timeout;
    $self->host('s3.amazonaws.com') if not defined $self->host;

    my $ua;
    if ($self->retry) {
        $ua = LWP::UserAgent::Determined->new(
            keep_alive            => $KEEP_ALIVE_CACHESIZE,
            requests_redirectable => [qw(GET HEAD DELETE PUT)],
        );
        $ua->timing('1,2,4,8,16,32');
    }
    else {
        $ua = LWP::UserAgent->new(
            keep_alive            => $KEEP_ALIVE_CACHESIZE,
            requests_redirectable => [qw(GET HEAD DELETE PUT)],
        );
    }

    $ua->timeout($self->timeout);
    $ua->env_proxy;
    $self->ua($ua);
    return $self;
}

sub buckets {
    my $self = shift;
    my $r = $self->_send_request('GET', '', {});

    return undef unless $r && !$self->_remember_errors($r);

    my $owner_id          = $r->{Owner}{ID};
    my $owner_displayname = $r->{Owner}{DisplayName};

    my @buckets;
    if (ref $r->{Buckets}) {
        my $buckets = $r->{Buckets}{Bucket};
        $buckets = [$buckets] unless ref $buckets eq 'ARRAY';
        foreach my $node (@$buckets) {
            push @buckets,
              Amazon::S3::Bucket->new(
                {   bucket        => $node->{Name},
                    creation_date => $node->{CreationDate},
                    account       => $self,
                }
              );

        }
    }
    return {
        owner_id          => $owner_id,
        owner_displayname => $owner_displayname,
        buckets           => \@buckets,
    };
}

sub add_bucket {
    my ($self, $conf) = @_;
    my $bucket = $conf->{bucket};
    croak 'must specify bucket' unless $bucket;

    if ($conf->{acl_short}) {
        $self->_validate_acl_short($conf->{acl_short});
    }

    my $header_ref =
        ($conf->{acl_short})
      ? {'x-amz-acl' => $conf->{acl_short}}
      : {};

    my $data = '';
    if (defined $conf->{location_constraint}) {
        $data =
            "<CreateBucketConfiguration><LocationConstraint>"
          . $conf->{location_constraint}
          . "</LocationConstraint></CreateBucketConfiguration>";
    }

    return 0
      unless $self->_send_request_expect_nothing('PUT', "$bucket/",
        $header_ref, $data);

    return $self->bucket($bucket);
}

sub bucket {
    my ($self, $bucketname) = @_;
    return Amazon::S3::Bucket->new({bucket => $bucketname, account => $self});
}

sub delete_bucket {
    my ($self, $conf) = @_;
    my $bucket;
    if (eval { $conf->isa("Amazon::S3::Bucket"); }) {
        $bucket = $conf->bucket;
    }
    else {
        $bucket = $conf->{bucket};
    }
    croak 'must specify bucket' unless $bucket;
    return $self->_send_request_expect_nothing('DELETE', $bucket . "/", {});
}

sub list_bucket {
    my ($self, $conf) = @_;
    my $bucket = delete $conf->{bucket};
    croak 'must specify bucket' unless $bucket;
    $conf ||= {};

    my $path = $bucket . "/";
    if (%$conf) {
        $path .= "?"
          . join('&',
            map { $_ . "=" . $self->_urlencode($conf->{$_}) } keys %$conf);
    }

    my $r = $self->_send_request('GET', $path, {});
    return undef unless $r && !$self->_remember_errors($r);
    my $return = {
        bucket       => $r->{Name},
        prefix       => $r->{Prefix},
        marker       => $r->{Marker},
        next_marker  => $r->{NextMarker},
        max_keys     => $r->{MaxKeys},
        is_truncated => (
            scalar $r->{IsTruncated} eq 'true'
            ? 1
            : 0
        ),
    };

    my @keys;
    foreach my $node (@{$r->{Contents}}) {
        my $etag = $node->{ETag};
        $etag =~ s{(^"|"$)}{}g if defined $etag;
        push @keys,
          { key               => $node->{Key},
            last_modified     => $node->{LastModified},
            etag              => $etag,
            size              => $node->{Size},
            storage_class     => $node->{StorageClass},
            owner_id          => $node->{Owner}{ID},
            owner_displayname => $node->{Owner}{DisplayName},
          };
    }
    $return->{keys} = \@keys;

    if ($conf->{delimiter}) {
        my @common_prefixes;
        my $strip_delim = qr/$conf->{delimiter}$/;

        foreach my $node ($r->{CommonPrefixes}) {
            my $prefix = $node->{Prefix};

            # strip delimiter from end of prefix
            $prefix =~ s/$strip_delim//;

            push @common_prefixes, $prefix;
        }
        $return->{common_prefixes} = \@common_prefixes;
    }

    return $return;
}

sub list_bucket_all {
    my ($self, $conf) = @_;
    $conf ||= {};
    my $bucket = $conf->{bucket};
    croak 'must specify bucket' unless $bucket;

    my $response = $self->list_bucket($conf);
    return $response unless $response->{is_truncated};
    my $all = $response;

    while (1) {
        my $next_marker = $response->{next_marker}
          || $response->{keys}->[-1]->{key};
        $conf->{marker} = $next_marker;
        $conf->{bucket} = $bucket;
        $response       = $self->list_bucket($conf);
        push @{$all->{keys}}, @{$response->{keys}};
        last unless $response->{is_truncated};
    }

    delete $all->{is_truncated};
    delete $all->{next_marker};
    return $all;
}

sub _validate_acl_short {
    my ($self, $policy_name) = @_;

    if (!grep({$policy_name eq $_}
            qw(private public-read public-read-write authenticated-read)))
    {
        croak "$policy_name is not a supported canned access policy";
    }
}

# EU buckets must be accessed via their DNS name. This routine figures out if
# a given bucket name can be safely used as a DNS name.
sub _is_dns_bucket {
    my $bucketname = $_[0];

    if (length $bucketname > 63) {
        return 0;
    }
    if (length $bucketname < 3) {
        return;
    }
    return 0 unless $bucketname =~ m{^[a-z0-9][a-z0-9.-]+$};
    my @components = split /\./, $bucketname;
    for my $c (@components) {
        return 0 if $c =~ m{^-};
        return 0 if $c =~ m{-$};
        return 0 if $c eq '';
    }
    return 1;
}

# make the HTTP::Request object
sub _make_request {
    my ($self, $method, $path, $headers, $data, $metadata) = @_;
    croak 'must specify method' unless $method;
    croak 'must specify path'   unless defined $path;
    $headers ||= {};
    $data = '' if not defined $data;
    $metadata ||= {};
    my $http_headers = $self->_merge_meta($headers, $metadata);

    $self->_add_auth_header($http_headers, $method, $path)
      unless exists $headers->{Authorization};
    my $protocol = $self->secure ? 'https' : 'http';
    my $host     = $self->host;
    my $url      = "$protocol://$host/$path";
    if ($path =~ m{^([^/?]+)(.*)} && _is_dns_bucket($1)) {
        $url = "$protocol://$1.$host$2";
    }

    my $request = HTTP::Request->new($method, $url, $http_headers);
    $request->content($data);

    # my $req_as = $request->as_string;
    # $req_as =~ s/[^\n\r\x20-\x7f]/?/g;
    # $req_as = substr( $req_as, 0, 1024 ) . "\n\n";
    # warn $req_as;

    return $request;
}

# $self->_send_request($HTTP::Request)
# $self->_send_request(@params_to_make_request)
sub _send_request {
    my $self = shift;
    my $request;
    if (@_ == 1) {
        $request = shift;
    }
    else {
        $request = $self->_make_request(@_);
    }

    my $response = $self->_do_http($request);
    my $content  = $response->content;

    return $content unless $response->content_type eq 'application/xml';
    return unless $content;
    return $self->_xpc_of_content($content);
}

# centralize all HTTP work, for debugging
sub _do_http {
    my ($self, $request, $filename) = @_;

    # convenient time to reset any error conditions
    $self->err(undef);
    $self->errstr(undef);
    return $self->ua->request($request, $filename);
}

sub _send_request_expect_nothing {
    my $self    = shift;
    my $request = $self->_make_request(@_);

    my $response = $self->_do_http($request);
    my $content  = $response->content;

    return 1 if $response->code =~ /^2\d\d$/;

    # anything else is a failure, and we save the parsed result
    $self->_remember_errors($response->content);
    return 0;
}

# Send a HEAD request first, to find out if we'll be hit with a 307 redirect.
# Since currently LWP does not have true support for 100 Continue, it simply
# slams the PUT body into the socket without waiting for any possible redirect.
# Thus when we're reading from a filehandle, when LWP goes to reissue the request
# having followed the redirect, the filehandle's already been closed from the
# first time we used it. Thus, we need to probe first to find out what's going on,
# before we start sending any actual data.
sub _send_request_expect_nothing_probed {
    my $self = shift;
    my ($method, $path, $conf, $value) = @_;
    my $request = $self->_make_request('HEAD', $path);
    my $override_uri = undef;

    my $old_redirectable = $self->ua->requests_redirectable;
    $self->ua->requests_redirectable([]);

    my $response = $self->_do_http($request);

    if ($response->code =~ /^3/ && defined $response->header('Location')) {
        $override_uri = $response->header('Location');
    }
    $request = $self->_make_request(@_);
    $request->uri($override_uri) if defined $override_uri;

    $response = $self->_do_http($request);
    $self->ua->requests_redirectable($old_redirectable);

    my $content = $response->content;

    return 1 if $response->code =~ /^2\d\d$/;

    # anything else is a failure, and we save the parsed result
    $self->_remember_errors($response->content);
    return 0;
}

sub _croak_if_response_error {
    my ($self, $response) = @_;
    unless ($response->code =~ /^2\d\d$/) {
        $self->err("network_error");
        $self->errstr($response->status_line);
        croak "Amazon::S3: Amazon responded with "
          . $response->status_line . "\n";
    }
}

sub _xpc_of_content {
    return XMLin($_[1], 'SuppressEmpty' => '', 'ForceArray' => ['Contents']);
}

# returns 1 if errors were found
sub _remember_errors {
    my ($self, $src) = @_;

    unless (ref $src || $src =~ m/^[[:space:]]*</) {    # if not xml
        (my $code = $src) =~ s/^[[:space:]]*\([0-9]*\).*$/$1/;
        $self->err($code);
        $self->errstr($src);
        return 1;
    }

    my $r = ref $src ? $src : $self->_xpc_of_content($src);

    if ($r->{Error}) {
        $self->err($r->{Error}{Code});
        $self->errstr($r->{Error}{Message});
        return 1;
    }
    return 0;
}

sub _add_auth_header {
    my ($self, $headers, $method, $path) = @_;
    my $aws_access_key_id     = $self->aws_access_key_id;
    my $aws_secret_access_key = $self->aws_secret_access_key;

    if (not $headers->header('Date')) {
        $headers->header(Date => time2str(time));
    }
    my $canonical_string = $self->_canonical_string($method, $path, $headers);
    my $encoded_canonical =
      $self->_encode($aws_secret_access_key, $canonical_string);
    $headers->header(
        Authorization => "AWS $aws_access_key_id:$encoded_canonical");
}

# generates an HTTP::Headers objects given one hash that represents http
# headers to set and another hash that represents an object's metadata.
sub _merge_meta {
    my ($self, $headers, $metadata) = @_;
    $headers  ||= {};
    $metadata ||= {};

    my $http_header = HTTP::Headers->new;
    while (my ($k, $v) = each %$headers) {
        $http_header->header($k => $v);
    }
    while (my ($k, $v) = each %$metadata) {
        $http_header->header("$METADATA_PREFIX$k" => $v);
    }

    return $http_header;
}

# generate a canonical string for the given parameters.  expires is optional and is
# only used by query string authentication.
sub _canonical_string {
    my ($self, $method, $path, $headers, $expires) = @_;
    my %interesting_headers = ();
    while (my ($key, $value) = each %$headers) {
        my $lk = lc $key;
        if (   $lk eq 'content-md5'
            or $lk eq 'content-type'
            or $lk eq 'date'
            or $lk =~ /^$AMAZON_HEADER_PREFIX/)
        {
            $interesting_headers{$lk} = $self->_trim($value);
        }
    }

    # these keys get empty strings if they don't exist
    $interesting_headers{'content-type'} ||= '';
    $interesting_headers{'content-md5'}  ||= '';

    # just in case someone used this.  it's not necessary in this lib.
    $interesting_headers{'date'} = ''
      if $interesting_headers{'x-amz-date'};

    # if you're using expires for query string auth, then it trumps date
    # (and x-amz-date)
    $interesting_headers{'date'} = $expires if $expires;

    my $buf = "$method\n";
    foreach my $key (sort keys %interesting_headers) {
        if ($key =~ /^$AMAZON_HEADER_PREFIX/) {
            $buf .= "$key:$interesting_headers{$key}\n";
        }
        else {
            $buf .= "$interesting_headers{$key}\n";
        }
    }

    # don't include anything after the first ? in the resource...
    $path =~ /^([^?]*)/;
    $buf .= "/$1";

    # ...unless there is an acl or torrent parameter
    if ($path =~ /[&?]acl($|=|&)/) {
        $buf .= '?acl';
    }
    elsif ($path =~ /[&?]torrent($|=|&)/) {
        $buf .= '?torrent';
    }
    elsif ($path =~ /[&?]location($|=|&)/) {
        $buf .= '?location';
    }

    return $buf;
}

sub _trim {
    my ($self, $value) = @_;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

# finds the hmac-sha1 hash of the canonical string and the aws secret access key and then
# base64 encodes the result (optionally urlencoding after that).
sub _encode {
    my ($self, $aws_secret_access_key, $str, $urlencode) = @_;
    my $hmac = Digest::HMAC_SHA1->new($aws_secret_access_key);
    $hmac->add($str);
    my $b64 = encode_base64($hmac->digest, '');
    if ($urlencode) {
        return $self->_urlencode($b64);
    }
    else {
        return $b64;
    }
}

sub _urlencode {
    my ($self, $unencoded) = @_;
    return uri_escape_utf8($unencoded, '^A-Za-z0-9_-');
}

1;

__END__

=head1 NAME

Amazon::S3 - A portable client library for working with and
managing Amazon S3 buckets and keys.

=head1 SYNOPSIS

  #!/usr/bin/perl
  use warnings;
  use strict;

  use Amazon::S3;
  
  use vars qw/$OWNER_ID $OWNER_DISPLAYNAME/;
  
  my $aws_access_key_id     = "Fill me in!";
  my $aws_secret_access_key = "Fill me in too!";
  
  my $s3 = Amazon::S3->new(
      {   aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
          retry                 => 1
      }
  );
  
  my $response = $s3->buckets;
  
  # create a bucket
  my $bucket_name = $aws_access_key_id . '-net-amazon-s3-test';
  my $bucket = $s3->add_bucket( { bucket => $bucket_name } )
      or die $s3->err . ": " . $s3->errstr;
  
  # store a key with a content-type and some optional metadata
  my $keyname = 'testing.txt';
  my $value   = 'T';
  $bucket->add_key(
      $keyname, $value,
      {   content_type        => 'text/plain',
          'x-amz-meta-colour' => 'orange',
      }
  );
  
  # list keys in the bucket
  $response = $bucket->list
      or die $s3->err . ": " . $s3->errstr;
  print $response->{bucket}."\n";
  for my $key (@{ $response->{keys} }) {
        print "\t".$key->{key}."\n";  
  }

  # delete key from bucket
  $bucket->delete_key($keyname);
  
  # delete bucket
  $bucket->delete_bucket;
  
=head1 DESCRIPTION

Amazon::S3 provides a portable client interface to Amazon Simple
Storage System (S3). 

"Amazon S3 is storage for the Internet. It is designed to
make web-scale computing easier for developers. Amazon S3
provides a simple web services interface that can be used to
store and retrieve any amount of data, at any time, from
anywhere on the web. It gives any developer access to the
same highly scalable, reliable, fast, inexpensive data
storage infrastructure that Amazon uses to run its own
global network of web sites. The service aims to maximize
benefits of scale and to pass those benefits on to
developers".

To sign up for an Amazon Web Services account, required to
use this library and the S3 service, please visit the Amazon
Web Services web site at http://www.amazonaws.com/.

You will be billed accordingly by Amazon when you use this
module and must be responsible for these costs.

To learn more about Amazon's S3 service, please visit:
http://s3.amazonaws.com/.

This need for this module arose from some work that needed
to work with S3 and would be distributed, installed and used
on many various environments where compiled dependencies may
not be an option. L<Net::Amazon::S3> used L<XML::LibXML>
tying it to that specific and often difficult to install
option. In order to remove this potential barrier to entry,
this module is forked and then modified to use L<XML::SAX>
via L<XML::Simple>.

Amazon::S3 is intended to be a drop-in replacement for
L<Net:Amazon::S3> that trades some performance in return for
portability.

=head1 METHODS

=head2 new 

Create a new S3 client object. Takes some arguments:

=over

=item aws_access_key_id 

Use your Access Key ID as the value of the AWSAccessKeyId parameter
in requests you send to Amazon Web Services (when required). Your
Access Key ID identifies you as the party responsible for the
request.

=item aws_secret_access_key 

Since your Access Key ID is not encrypted in requests to AWS, it
could be discovered and used by anyone. Services that are not free
require you to provide additional information, a request signature,
to verify that a request containing your unique Access Key ID could
only have come from you.

B<DO NOT INCLUDE THIS IN SCRIPTS OR APPLICATIONS YOU
DISTRIBUTE. YOU'LL BE SORRY.>

=item secure

Set this to C<1> if you want to use SSL-encrypted
connections when talking to S3. Defaults to C<0>.

=item timeout

Defines the time, in seconds, your script should wait or a
response before bailing. Defaults is 30 seconds.

=item retry

Enables or disables the library to retry upon errors. This
uses exponential backoff with retries after 1, 2, 4, 8, 16,
32 seconds, as recommended by Amazon. Defaults to off, no
retries.

=item host

Defines the S3 host endpoint to use. Defaults to
's3.amazonaws.com'.

=back

=head2 buckets

Returns C<undef> on error, else HASHREF of results:

=over

=item owner_id

The owner's ID of the buckets owner.

=item owner_display_name

The name of the owner account. 

=item buckets

Any ARRAYREF of L<Amazon::SimpleDB::Bucket> objects for the 
account.

=back

=head2 add_bucket 

Takes a HASHREF:

=over

=item bucket

The name of the bucket you want to add

=item acl_short (optional)

See the set_acl subroutine for documenation on the acl_short options

=back

Returns 0 on failure or a L<Amazon::S3::Bucket> object on success

=head2 bucket BUCKET

Takes a scalar argument, the name of the bucket you're creating

Returns an (unverified) bucket object from an account. This method does not access the network.

=head2 delete_bucket

Takes either a L<Amazon::S3::Bucket> object or a HASHREF containing 

=over

=item bucket

The name of the bucket to remove

=back

Returns false (and fails) if the bucket isn't empty.

Returns true if the bucket is successfully deleted.

=head2 list_bucket

List all keys in this bucket.

Takes a HASHREF of arguments:

=over

=item bucket

REQUIRED. The name of the bucket you want to list keys on.

=item prefix

Restricts the response to only contain results that begin with the
specified prefix. If you omit this optional argument, the value of
prefix for your query will be the empty string. In other words, the
results will be not be restricted by prefix.

=item delimiter

If this optional, Unicode string parameter is included with your
request, then keys that contain the same string between the prefix
and the first occurrence of the delimiter will be rolled up into a
single result element in the CommonPrefixes collection. These
rolled-up keys are not returned elsewhere in the response.  For
example, with prefix="USA/" and delimiter="/", the matching keys
"USA/Oregon/Salem" and "USA/Oregon/Portland" would be summarized
in the response as a single "USA/Oregon" element in the CommonPrefixes
collection. If an otherwise matching key does not contain the
delimiter after the prefix, it appears in the Contents collection.

Each element in the CommonPrefixes collection counts as one against
the MaxKeys limit. The rolled-up keys represented by each CommonPrefixes
element do not.  If the Delimiter parameter is not present in your
request, keys in the result set will not be rolled-up and neither
the CommonPrefixes collection nor the NextMarker element will be
present in the response.

NOTE: CommonPrefixes isn't currently supported by Amazon::S3. 

=item max-keys 

This optional argument limits the number of results returned in
response to your query. Amazon S3 will return no more than this
number of results, but possibly less. Even if max-keys is not
specified, Amazon S3 will limit the number of results in the response.
Check the IsTruncated flag to see if your results are incomplete.
If so, use the Marker parameter to request the next page of results.
For the purpose of counting max-keys, a 'result' is either a key
in the 'Contents' collection, or a delimited prefix in the
'CommonPrefixes' collection. So for delimiter requests, max-keys
limits the total number of list results, not just the number of
keys.

=item marker

This optional parameter enables pagination of large result sets.
C<marker> specifies where in the result set to resume listing. It
restricts the response to only contain results that occur alphabetically
after the value of marker. To retrieve the next page of results,
use the last key from the current page of results as the marker in
your next request.

See also C<next_marker>, below. 

If C<marker> is omitted,the first page of results is returned. 

=back

Returns C<undef> on error and a HASHREF of data on success:

The HASHREF looks like this:

  {
        bucket       => $bucket_name,
        prefix       => $bucket_prefix, 
        marker       => $bucket_marker, 
        next_marker  => $bucket_next_available_marker,
        max_keys     => $bucket_max_keys,
        is_truncated => $bucket_is_truncated_boolean
        keys          => [$key1,$key2,...]
   }

Explanation of bits of that:

=over

=item is_truncated

B flag that indicates whether or not all results of your query were
returned in this response. If your results were truncated, you can
make a follow-up paginated request using the Marker parameter to
retrieve the rest of the results.

=item next_marker 

A convenience element, useful when paginating with delimiters. The
value of C<next_marker>, if present, is the largest (alphabetically)
of all key names and all CommonPrefixes prefixes in the response.
If the C<is_truncated> flag is set, request the next page of results
by setting C<marker> to the value of C<next_marker>. This element
is only present in the response if the C<delimiter> parameter was
sent with the request.

=back

Each key is a HASHREF that looks like this:

     {
        key           => $key,
        last_modified => $last_mod_date,
        etag          => $etag, # An MD5 sum of the stored content.
        size          => $size, # Bytes
        storage_class => $storage_class # Doc?
        owner_id      => $owner_id,
        owner_displayname => $owner_name
    }

=head2 list_bucket_all

List all keys in this bucket without having to worry about
'marker'. This is a convenience method, but may make multiple requests
to S3 under the hood.

Takes the same arguments as list_bucket.

=head1 ABOUT

This module contains code modified from Amazon that contains the
following notice:

  #  This software code is made available "AS IS" without warranties of any
  #  kind.  You may copy, display, modify and redistribute the software
  #  code either by itself or as incorporated into your code; provided that
  #  you do not remove any proprietary notices.  Your use of this software
  #  code is at your own risk and you waive any claim against Amazon
  #  Digital Services, Inc. or its affiliates with respect to your use of
  #  this software code. (c) 2006 Amazon Digital Services, Inc. or its
  #  affiliates.

=head1 TESTING

Testing S3 is a tricky thing. Amazon wants to charge you a bit of 
money each time you use their service. And yes, testing counts as using.
Because of this, the application's test suite skips anything approaching 
a real test unless you set these three environment variables:

=over 

=item AMAZON_S3_EXPENSIVE_TESTS

Doesn't matter what you set it to. Just has to be set

=item AWS_ACCESS_KEY_ID 

Your AWS access key

=item AWS_ACCESS_KEY_SECRET

Your AWS sekkr1t passkey. Be forewarned that setting this environment variable
on a shared system might leak that information to another user. Be careful.

=back

=head1 TO DO

=over

=item Continued to improve and refine of documentation.

=item Reduce dependencies wherever possible.

=item Implement debugging mode

=item Refactor and consolidate request code in Amazon::S3

=item Refactor URI creation code to make use of L<URI>.

=back

=head1 SUPPORT

Bugs should be reported via the CPAN bug tracker at

<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Amazon-S3>

For other issues, contact the author.

=head1 AUTHOR

Timothy Appnel <tima@cpan.org>

=head1 SEE ALSO

L<Amazon::S3::Bucket>, L<Net::Amazon::S3>

=head1 COPYRIGHT AND LICENCE

This module was initially based on L<Net::Amazon::S3> 0.41, by
Leon Brocard. Net::Amazon::S3 was based on example code from
Amazon with this notice:

#  This software code is made available "AS IS" without warranties of any
#  kind.  You may copy, display, modify and redistribute the software
#  code either by itself or as incorporated into your code; provided that
#  you do not remove any proprietary notices.  Your use of this software
#  code is at your own risk and you waive any claim against Amazon
#  Digital Services, Inc. or its affiliates with respect to your use of
#  this software code. (c) 2006 Amazon Digital Services, Inc. or its
#  affiliates.

The software is released under the Artistic License. The
terms of the Artistic License are described at
http://www.perl.com/language/misc/Artistic.html. Except
where otherwise noted, Amazon::S3 is Copyright 2008, Timothy
Appnel, tima@cpan.org. All rights reserved.
