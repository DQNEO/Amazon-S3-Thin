package Amazon::S3::Thin::Signer;

=head1 NAME

Amazon::S3::Thin::Signer - Base class and factory for signers

=head1 SYNOPSIS

    # create a client object
    my $s3client = Amazon::S3::Thin->new({
      aws_access_key_id => $aws_access_key_id,
      aws_secret_access_key => $secret_access_key,
      signature_version => 4,   # optional
    });

    # create an object that can sign requests
    my $signer = Amazon::S3::Thin::Signer->factory($s3client);

    # create a request
    my $request = HTTP::Request->new(...);

    # sign the request using the client keys
    $signer->sign($request);

=head1 DESCRIPTION

This module is used to construct an object that can sign an AWS request using
the access keys and requested signature version from an Amazon::S3::Thin client
object.

You do not need to use this module directly; signers are created automatically
and used to sign requests generated within the Amazon::S3::Thin module.

=cut

use strict;
use warnings;

=head1 CONSTRUCTORS

=cut


=head2 new($client)

Constructs a new object and copies all the parameters of the C<$client> object
to the signer object. Subclasses will inherit this constructor.

=cut

sub new
{
  my ($class, $thin) = @_;
  my $self = { %$thin };
  bless $self, $class;
}

=head1 METHODS

=head2 sign($request)

Subclasses must override this method with specific implementation to add a signature
to the supplied C<$request>.

=cut

sub sign
{
  my ($self, $request) = @_;
  die ref($self) . ' does not implement sign method';
}

1;

=head1 LICENSE

Copyright (C) 2016, Robert Showalter

This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

Robert Showalter
