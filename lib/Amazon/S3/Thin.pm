package Amazon::S3::Thin;
use 5.008001;
use strict;
use warnings;

use Carp;
use HTTP::Date ();
use LWP::UserAgent;
use URI::Escape qw(uri_escape_utf8);
use Amazon::S3::Thin::SignerV2;

our $VERSION = '0.09';

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

sub head_object {
    my ($self, $bucket, $key) = @_;
    my $request = $self->_compose_request('HEAD', $self->_uri($bucket, $key));
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

sub _urlencode {
    my ($self, $unencoded) = @_;
    return uri_escape_utf8($unencoded, '^A-Za-z0-9_-');
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
    my ($self, $bucketname) = @_;

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

        my $signer = Amazon::S3::Thin::SignerV2->new($self->{aws_secret_access_key});
        my $signature = $signer->calculate_signature($method, $path, $http_headers);
        $http_headers->header(
            Authorization => sprintf("AWS %s:%s"
                                     , $self->{aws_access_key_id}
                                     , $signature));
    }

    my $protocol = $self->secure ? 'https' : 'http';
    my $host     = $self->host;
    my $url;

    if ($path =~ m{^([^/?]+)(.*)} && $self->_is_dns_bucket($1)) {
        $url = "$protocol://$1.$host$2";
    } else {
        $url = "$protocol://$host/$path";
    }

    return HTTP::Request->new($method, $url, $http_headers, $content);
}


1;

__END__

=head1 NAME

Amazon::S3::Thin - A thin, lightweight, low-level Amazon S3 client

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

  $response = $s3client->head_object($bucket, $key);

You can also pass any useragent as you like

  my $s3client = Amazon::S3::Thin->new(
      {   aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
          ua                    => $any_LWP_copmatible_useragent,
      }
  );


=head1 DESCRIPTION

Amazon::S3::Thin is a thin, lightweight, low-level Amazon S3 client.
It offers the following features:

=over

=item Low Level

It returns L<HTTP::Response> objects so you can easily inspect
what's happening inside, and can handle errors as you like.


=item Low Dependency

It does not require any XML::* modules, so installation is easy;

=item Low Learning Cost

The interfaces are designed to follow S3 official REST APIs.
So it is easy to learn.

=back

=head2 Comparison to precedent modules

There are already some useful modules like L<Amazon::S3>, L<Net::Amazon::S3>
and L<AWS::S3> on CPAN. They provide a "Perlish" interface, which looks pretty
 for Perl programmers, but they also hide low-level behaviors.
For example, the "get_key" method translate HTTP status 404 into C<undef> and
 HTTP 5xx status into exception.

In some situations, it is very important to see the raw HTTP communications.
That's why I made this module.

=head1 CONSTRUCTOR

=head2 new( \%params )

B<Receives:> hashref with options.

B<Returns:> Amazon::S3::Thin object

It can receive the following arguments:

=over 4

=item * C<aws_access_key_id> (B<REQUIRED>) - the access key id
for your S3 account.

=item * C<aws_secret_access_key> (B<REQUIRED>) - the secret access key
for your S3 account.

=item * C<secure> - whether to use https or not. Default is 0 (http).

=item * C<host> - the base host to use. Default is 'I<s3.amazonaws.com>'.

=item * C<ua> - a user agent object, compatible with LWP::UserAgent.
Default is an instance of L<LWP::UserAgent>.

=back

=head1 ACCESSORS

The following accessors are provided. You can use them to get/set your
object's attributes.

=head2 secure

Whether to use https (1) or http (0) when connecting to S3.

=head2 host

The base host to use for connecting to S3.

=head2 ua

The user agent used internally to perform requests and return responses.
If you set this attribute, please make sure you do so with an object
compatible with L<LWP::UserAgent> (i.e. providing the same interface).

=head1 METHODS

=head2 get_object( $bucket, $key )

B<Arguments>: a string with the bucket name, and a string with the key name.

B<Returns>: an L<HTTP::Response> object for the request. Use the C<content()>
method on the returned object to read the contents:

    my $res = $s3->get_object( 'my.bucket', 'my/key.ext' );

    if ($res->is_success) {
        my $content = $res->content;
    }

The GET operation retrieves an object from Amazon S3.

For more information, please refer to
L<< Amazon's documentation for GET|http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectGET.html >>.

=head2 delete_object( $bucket, $key )

B<Arguments>: a string with the bucket name, and a string with the key name.

B<Returns>: an L<HTTP::Response> object for the request.

The DELETE operation removes the null version (if there is one) of an object
and inserts a delete marker, which becomes the current version of the
object. If there isn't a null version, Amazon S3 does not remove any objects.

Use the response object to see if it succeeded or not.

For more information, please refer to
L<< Amazon's documentation for DELETE|http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectDELETE.html >>.

=head2 copy_object( $src_bucket, $src_key, $dst_bucket, $dst_key )

B<Arguments>: a list with source (bucket, key) and destination (bucket, key)

B<Returns>: an L<HTTP::Response> object for the request.

This method is a variation of the PUT operation as described by
Amazon's S3 API. It creates a copy of an object that is already stored
in Amazon S3. This "PUT copy" operation is the same as performing a GET
from the old bucket/key and then a PUT to the new bucket/key.

For more information, please refer to
L<< Amazon's documentation for COPY|http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectCOPY.html >>.

=head2 put_object( $bucket, $key, $content [, $headers] )

B<Arguments>:

a list of the following items, in order:

=over 4

=item 1. bucket - a string with the destination bucket

=item 2. key - a string with the destination key

=item 3. content - a string with the content to be uploaded

=item 4. headers (B<optional>) - hashref with extra headr information

=back

B<Returns>: an L<HTTP::Response> object for the request.

The PUT operation adds an object to a bucket. Amazon S3 never adds partial
objects; if you receive a success response, Amazon S3 added the entire
object to the bucket.

For more information, please refer to
L<< Amazon's documentation for PUT|http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html >>.


=head1 TODO

lots of APIs are not implemented yet.

=head1 REPOSITORY

L<https://github.com/DQNEO/Amazon-S3-Thin>

=head1 LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

DQNEO

=head2 ORIGINAL AUTHOR

Timothy Appnel <tima@cpan.org> L<Amazon::S3>
L<https://github.com/tima/perl-amazon-s3>

=head1 SEE ALSO

L<Amazon::S3>, L<Net::Amazon::S3>, L<AWS::S3>.

L<Amazon S3 API Reference : REST API|http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html>

L<Amazon S3 API Reference : List of Error Codes|http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList>

=cut
