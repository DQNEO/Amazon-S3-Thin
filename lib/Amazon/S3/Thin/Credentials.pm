package Amazon::S3::Thin::Credentials;

=head1 NAME

Amazon::S3::Thin::Credentials - AWS credentials data container

=head1 SYNOPSIS

    my $credentials = Amazon::S3::Thin::Credentials->new(
        $aws_access_key_id, $aws_secret_access_key
    );
    
    my $key = $credentials->access_key_id();
    my $secret = $credentials->secret_access_key();

1;

=head1 DESCRIPTION

This module contains aws credentials and provide getters to the data.

=cut

use strict;
use warnings;

sub new {
    my ($class, $key, $secret) = @_;
    my $self = {
        key => $key,
        secret => $secret,
    };
    return bless $self, $class;
}

=head2 access_key_id()

Returns access_key_id

=cut

sub access_key_id {
    my $self = shift;
    return $self->{key};
}

=head2 secret_access_key()

Returns secret_access_key

=cut
    
sub secret_access_key {
    my $self = shift;
    return $self->{secret};
}

1;
