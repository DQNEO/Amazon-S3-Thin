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
    $signer->sign_request($request);

=head1 DESCRIPTION

This module creates objects that can sign AWS requests using signature version
4, as implemented by the L<AWS::Signature4> module.

=cut

use strict;
use warnings;

use AWS::Signature4;

use parent 'Amazon::S3::Thin::Signer';

=head1 METHODS

=head2 sign_request($request)

Signs supplied L<HTTP::Request> object, adding required AWS headers.

=cut

sub sign_request
{
  my ($self, $request) = @_;
  my $signer = $self->signer;
  my $digest = Digest::SHA::sha256_hex($request->content);
  $request->header('X-Amz-Content-SHA256', $digest);
  $DB::single = 1;
  $signer->sign($request, $self->{aws_region}, $digest);
  $request;
}

=head2 signer

Returns an L<AWS::Signature4> object for signing requests

=cut

sub signer
{
  my $self = shift;
  AWS::Signature4->new(
    -access_key => $self->{aws_access_key_id},
    -secret_key => $self->{aws_secret_access_key},
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
