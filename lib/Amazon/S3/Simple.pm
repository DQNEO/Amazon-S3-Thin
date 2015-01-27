package Amazon::S3::Simple;
use strict;
use warnings;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(aws_access_key_id aws_secret_access_key)
);

sub new {
    my $self  = $class->SUPER::new(@_);
    return $self;
}

# return HTTP::Response
sub get_object {

}

# return HTTP::Response
sub put_object {

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

  my $response = $s3client->get_object($bucket, $key);

  my $response = $s3client->put_object($bucket, $key, $content);

=head1 AUTHOR

DQNEQ








