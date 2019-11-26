package Amazon::S3::Thin::Signer::V4;

=head1 NAME

Amazon::S3::Thin::Signer::V4 - AWS Version 4 Signer

=head1 SYNOPSIS

    # create a client object
    my $s3client = Amazon::S3::Thin->new({
      aws_access_key_id => $aws_access_key_id,
      aws_secret_access_key => $secret_access_key,
    });

    # create a signer
    my $signer = Amazon::S3::Thin::Signer::V4->new($s3client);

    # create a request
    my $request = HTTP::Request->new(...);

    # sign the request using the client keys
    $signer->sign($request);

=head1 DESCRIPTION

This module creates objects that can sign AWS requests using signature version
4, as implemented by the L<AWS::Signature4> module.

=cut

use strict;
use warnings;
use AWS::Signature4;
use Digest::SHA ();
use JSON::PP ();
use MIME::Base64 ();
use POSIX 'strftime';

sub new {
    my ($class, $credentials, $region) = @_;
    my $self = {
        credentials => $credentials,
        region => $region,
    };
    bless $self, $class;
}

=head1 METHODS

=head2 sign($request)

Signs supplied L<HTTP::Request> object, adding required AWS headers.

=cut

sub sign
{
  my ($self, $request) = @_;
  my $signer = $self->signer;
  if (defined $self->{credentials}->session_token) {
    $request->header('X-Amz-Security-Token', $self->{credentials}->session_token);
  }
  my $digest = Digest::SHA::sha256_hex($request->content);
  $request->header('X-Amz-Content-SHA256', $digest);
  $signer->sign($request, $self->{region}, $digest);
  $request;
}

=head2 signer

Returns an L<AWS::Signature4> object for signing requests

=cut

sub signer
{
  my $self = shift;
  AWS::Signature4->new(
    -access_key => $self->{credentials}->access_key_id,
    -secret_key => $self->{credentials}->secret_access_key,
  );
}

# This method is written referencing these botocore's implementations:
# https://github.com/boto/botocore/blob/00c4cadcf0996ef77a3a01b158f15c8fced9909b/botocore/signers.py#L602-L714
# https://github.com/boto/botocore/blob/00c4cadcf0996ef77a3a01b158f15c8fced9909b/botocore/signers.py#L459-L528
# https://github.com/boto/botocore/blob/00c4cadcf0996ef77a3a01b158f15c8fced9909b/botocore/auth.py#L585-L628
sub _generate_presigned_post {
    my ($self, $bucket, $key, $fields, $conditions, $expires_in) = @_;

    # $fields is arrayref of key/value pairs. The order of the fields is important because AWS says "please check the order of the fields"...
    $fields ||= [];
    $conditions ||= [];
    $expires_in ||= 3600;

    my $t = time;
    my $datetime = strftime('%Y%m%dT%H%M%SZ', gmtime($t));
    my $expiration = strftime('%Y-%m-%dT%H:%M:%SZ', gmtime($t + $expires_in));

    my $signer = $self->signer;
    my ($date) = $datetime =~ /^(\d+)T/;
    my $credential = $signer->access_key . '/' . $date . '/' . $self->{region} . '/s3/aws4_request';

    push @$conditions, {bucket => $bucket};

    push @$fields, key => $key;
    if ($key =~ /\$\{filename\}$/) {
        push @$conditions, ['starts-with' => '$key', substr($key, 0, -11)];
    } else {
        push @$conditions, {key => $key};
    }

    push @$fields, 'x-amz-algorithm' => 'AWS4-HMAC-SHA256';
    push @$fields, 'x-amz-credential' => $credential;
    push @$fields, 'x-amz-date' => $datetime;

    push @$conditions, {'x-amz-algorithm' => 'AWS4-HMAC-SHA256'};
    push @$conditions, {'x-amz-credential' => $credential};
    push @$conditions, {'x-amz-date' => $datetime};

    my $session_token = $self->{credentials}->session_token;
    if (defined $session_token) {
        push @$fields, 'x-amz-security-token' => $session_token;
        push @$conditions, {'x-amz-security-token' => $session_token};
    }

    my $policy = $self->_encode_policy({
        expiration => $expiration,
        conditions => $conditions,
    });
    push @$fields, policy => $policy;

    my $signing_key = $signer->signing_key(
        $signer->secret_key,
        's3',
        $self->{region},
        $date,
    );
    push @$fields, 'x-amz-signature' => Digest::SHA::hmac_sha256_hex($policy, $signing_key);

    return $fields;
}

my $_JSON;
sub _encode_policy {
    my $self = shift;
    return MIME::Base64::encode_base64(
        ($_JSON ||= JSON::PP->new->utf8->canonical)->encode(@_),
        ''
    );
}

1;

=head1 LICENSE

Copyright (C) 2016, Robert Showalter

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Robert Showalter

=head1 SEE ALSO

L<AWS::Signature4>
