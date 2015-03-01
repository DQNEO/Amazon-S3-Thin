package Amazon::S3::Thin;
use 5.008001;
use strict;
use warnings;

use Carp;
use Digest::HMAC_SHA1;
use HTTP::Date ();
use MIME::Base64 ();
use LWP::UserAgent;
use URI::Escape qw(uri_escape_utf8);

our $VERSION = '0.06';

my $AMAZON_HEADER_PREFIX = 'x-amz-';
my $METADATA_PREFIX      = 'x-amz-meta-';

sub new {
    my $class = shift;
    my $self  = shift;

    bless $self, $class;

    die "No aws_access_key_id"     unless $self->{aws_access_key_id};
    die "No aws_secret_access_key" unless $self->{aws_secret_access_key};

    $self->secure(0)                unless defined $self->secure;
    $self->host('s3.amazonaws.com') unless defined $self->host;
    $self->ua($self->_default_ua)   unless defined $self->ua;

    return $self;
}

sub _default_ua {
    my $self = shift;

    my $ua = LWP::UserAgent->new(
        keep_alive            => 10,
        requests_redirectable => [qw(GET HEAD DELETE PUT)],
        );
    $ua->timeout(30);
    $ua->env_proxy;
    return $ua;
}

# accessor
sub secure {
    my $self = shift;
    if (@_) {
        $self->{secure} = shift;
    } else {
        return $self->{secure};
    }
}

# accessor
sub host {
    my $self = shift;
    if (@_) {
        $self->{host} = shift;
    } else {
        return $self->{host};
    }
}

# accessor
sub ua {
    my $self = shift;
    if (@_) {
        $self->{ua} = shift;
    } else {
        return $self->{ua};
    }
}

sub get_object {
    my ($self, $bucket, $key) = @_;
    my $request = $self->_compose_request('GET', $self->_uri($bucket, $key));
    return $self->ua->request($request);
}

sub delete_object {
    my ($self, $bucket, $key) = @_;
    my $request = $self->_compose_request('DELETE', $self->_uri($bucket, $key));
    return $self->ua->request($request);
}

sub copy_object {
    my ($self, $src_bucket, $src_key, $dst_bucket, $dst_key) = @_;
    my $headers = {};
    $headers->{'x-amz-copy-source'} = $src_bucket . "/" . $src_key;
    my $request = $self->_compose_request('PUT', $self->_uri($dst_bucket, $dst_key), $headers);
    return $self->ua->request($request);
}

sub put_object {
    my ($self, $bucket, $key, $content, $headers) = @_;
    croak 'must specify key' unless $key && length $key;
    
    if ($headers->{acl_short}) {
        $self->_validate_acl_short($headers->{acl_short});
        $headers->{'x-amz-acl'} = $headers->{acl_short};
        delete $headers->{acl_short};
    }

    if (ref($content) eq 'SCALAR') {
        $headers->{'Content-Length'} ||= -s $$content;
        $content = _content_sub($$content);
    }
    else {
        $headers->{'Content-Length'} ||= length $content;
    }

    if (ref($content)) {
        # TODO
        # I do not understand what it is :(
        #
        # return $self->_send_request_expect_nothing_probed('PUT',
        #    $self->_uri($bucket, $key), $headers, $content);
        #
        die "unable to handle reference";
    }
    else {
        my $request = $self->_compose_request('PUT', $self->_uri($bucket, $key), $headers, $content);
        return $self->ua->request($request);
    }
}

# http://docs.aws.amazon.com/AmazonS3/latest/API/RESTBucketGET.html
sub list_objects {
    my ($self, $bucket, $opt) = @_;
    croak 'must specify bucket' unless $bucket;
    $opt ||= {};

    my $path = $bucket . "/";
    if (%$opt) {
        $path .= "?"
          . join('&',
            map { $_ . "=" . $self->_urlencode($opt->{$_}) } sort keys %$opt);
    }

    my $request = $self->_compose_request('GET', $path);
    my $response = $self->ua->request($request);
    return $response;
}

sub _uri {
    my ($self, $bucket, $key) = @_;
    return ($key)
      ? $bucket . "/" . $self->_urlencode($key)
      : $bucket . "/";
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
sub _compose_request {
    my ($self, $method, $path, $headers, $content, $metadata) = @_;
    croak 'must specify method' unless $method;
    croak 'must specify path'   unless defined $path;
    $headers ||= {};
    $metadata ||= {};

    # generates an HTTP::Headers objects given one hash that represents http
    # headers to set and another hash that represents an object's metadata.
    my $http_headers = HTTP::Headers->new;
    while (my ($k, $v) = each %$headers) {
        $http_headers->header($k => $v);
    }
    while (my ($k, $v) = each %$metadata) {
        $http_headers->header("$METADATA_PREFIX$k" => $v);
    }

    # do we need check existance of Authorization ?
    if (! exists $headers->{Authorization}) {
        if (not $http_headers->header('Date')) {
            $http_headers->header(Date => HTTP::Date::time2str(time));
        }
        my $string_to_sign = $self->_generate_string_to_sign($method, $path, $http_headers);

        my $hmac = Digest::HMAC_SHA1->new($self->{aws_secret_access_key});
        $hmac->add($string_to_sign);
        my $signature =  MIME::Base64::encode_base64($hmac->digest, '');

        $http_headers->header(
            Authorization => sprintf("AWS %s:%s"
                                     , $self->{aws_access_key_id}
                                     , $signature));
    }

    my $protocol = $self->secure ? 'https' : 'http';
    my $host     = $self->host;
    my $url;

    if ($path =~ m{^([^/?]+)(.*)} && _is_dns_bucket($1)) {
        $url = "$protocol://$1.$host$2";
    } else {
        $url = "$protocol://$host/$path";
    }

    return HTTP::Request->new($method, $url, $http_headers, $content);
}

# generate a canonical string for the given parameters.  expires is optional and is
# only used by query string authentication.
sub _generate_string_to_sign {
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

sub _urlencode {
    my ($self, $unencoded) = @_;
    return uri_escape_utf8($unencoded, '^A-Za-z0-9_-');
}

1;

__END__

=head1 NAME

Amazon::S3::Thin - A thin, ligthweight, low-level Amazon S3 client

=head1 SYNOPSIS

  use Amazon::S3::Thin;

  my $s3client = Amazon::S3::Thin->new(
      {   aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
      }
  );

  my $key = "dir/file.txt";
  my $response;
  $response = $s3client->put_object($bucket, $key, "hello world");

  $response = $s3client->get_object($bucket, $key);
  print $response->content; # => "hello world"

  $response = $s3client->delete_object($bucket, $key);

  $response = $s3client->copy_object($src_bucket, $src_key,
                                     $dst_bucket, $dst_key);

  $response = $s3client->list_objects(
                              $bucket,
                              {prefix => "foo", delimter => "/"}
                             );

You can also pass any useragent as you like

  my $s3client = Amazon::S3::Thin->new(
      {   aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
          ua                    => $any_LWP_copmatible_useragent,
      }
  );


=head1 DESCRIPTION

Amazon::S3::Thin - A thin, ligthweight, low-level Amazon S3 client.

=over

=item Low Level

It returns HTTP::Response. So you can inspect easily what's happening inside , and can handle error as you like.


=item Low Dependency

It does require no XML::* modules, so that installation be easy;

=item Low Learning Cost

The interfaces are designed to follow S3 official REST APIs. So it is easy to learn.

=back

=head1 comparison to precedent modules

There are already usuful modules L<Amazon::S3> and L<Net::Amazon::S3>.
The 2 precedent modules provides "a Perlish interface", which is easy to understand for Perl programmers.
But they also hide low-level behaviors.
For example, the "get_key" method returns undef on 404 status and raises exception on 5xx status.

In some situations, it is very important to see raw HTTP communications.
That's why I made this module.

=head1 TO DO

lots of APIs are not implemented yet.

=head1 SUPPORT

Bugs should be reported via Github

https://github.com/DQNEO/Amazon-S3-Thin/issues

=head1 LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

DQNEO

=head2 ORIGINAL AUTHOR

Timothy Appnel <tima@cpan.org> L<Amazon::S3>

=head1 SEE ALSO

L<Amazon::S3>, L<Net::Amazon::S3>

API Reference : REST API
http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html

API Reference : List of Error Codes
http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList

=cut
