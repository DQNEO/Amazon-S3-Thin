package Amazon::S3::Simple;
use 5.008001;
use strict;
use warnings;

use Carp;
use Digest::HMAC_SHA1;
use HTTP::Date;
use MIME::Base64 qw(encode_base64);
use LWP::UserAgent;
use URI::Escape qw(uri_escape_utf8);
use HTTP::Response;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(aws_access_key_id aws_secret_access_key secure host ua)
);

our $VERSION = '0.01';

my $AMAZON_HEADER_PREFIX = 'x-amz-';
my $METADATA_PREFIX      = 'x-amz-meta-';
my $KEEP_ALIVE_CACHESIZE = 10;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    die "No aws_access_key_id"     unless $self->aws_access_key_id;
    die "No aws_secret_access_key" unless $self->aws_secret_access_key;

    $self->secure(0)                if not defined $self->secure;
    $self->host('s3.amazonaws.com') if not defined $self->host;

    if (! defined $self->ua) {
        $self->ua($self->_default_ua);
    }

    return $self;
}

sub _default_ua {
    my $self = shift;

    my $ua = LWP::UserAgent->new(
        keep_alive            => $KEEP_ALIVE_CACHESIZE,
        requests_redirectable => [qw(GET HEAD DELETE PUT)],
        );
    $ua->timeout(30);
    $ua->env_proxy;
    return $ua;
}

sub get_object {
    my ($self, $bucket, $key) = @_;
    my $request = $self->_compose_request('GET', $self->_uri($bucket, $key), {});
    return $self->ua->request($request);
}

sub delete_object {
    my ($self, $bucket, $key) = @_;
    my $request = $self->_compose_request('DELETE', $self->_uri($bucket, $key), {});
    return $self->ua->request($request);
}

sub put_object {
    my ($self, $bucket, $key, $content, $conf) = @_;
    croak 'must specify key' unless $key && length $key;
    
    if ($conf->{acl_short}) {
        $self->_validate_acl_short($conf->{acl_short});
        $conf->{'x-amz-acl'} = $conf->{acl_short};
        delete $conf->{acl_short};
    }

    if (ref($content) eq 'SCALAR') {
        $conf->{'Content-Length'} ||= -s $$content;
        $content = _content_sub($$content);
    }
    else {
        $conf->{'Content-Length'} ||= length $content;
    }

    if (ref($content)) {
        # TODO
        # I do not understand what it is :(
        #
        # return $self->_send_request_expect_nothing_probed('PUT',
        #    $self->_uri($bucket, $key), $conf, $content);
        #
        die "unable to handle reference";
    }
    else {
        my $request = $self->_compose_request('PUT', $self->_uri($bucket, $key), $conf, $content);
        return $self->ua->request($request);
    }
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
    my $http_headers = $self->_merge_meta($headers, $metadata);

    $self->_add_auth_header($http_headers, $method, $path)
      unless exists $headers->{Authorization};
    my $protocol = $self->secure ? 'https' : 'http';
    my $host     = $self->host;
    my $url      = "$protocol://$host/$path";
    if ($path =~ m{^([^/?]+)(.*)} && _is_dns_bucket($1)) {
        $url = "$protocol://$1.$host$2";
    }

    return HTTP::Request->new($method, $url, $http_headers, $content);
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

Amazon::S3::Simple - A very simple Amazon S3 client

=head1 SYNOPSIS

  use strict;
  use warnings;
  use Amazon::S3::Simple;

  my $s3client = Amazon::S3::Simple->new(
      {   aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
      }
  );

  $response = $s3client->get_object($bucket, $key);

  my $content = "hello world";
  $response = $s3client->put_object($bucket, $key, $content);


=head1 LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

DQNEO

=cut








