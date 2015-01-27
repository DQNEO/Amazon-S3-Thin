package Amazon::S3::Simple;
use strict;
use warnings;
use HTTP::Response;

use Amazon::S3;
use Amazon::S3::Bucket;


use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(aws_access_key_id aws_secret_access_key)
);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{s3} = Amazon::S3->new(@_);
    return $self;
}

sub get_object {
    my ($self, $bucket, $key) = @_;
    my $ob = $self->{s3}->bucket($bucket) or die 'cannot get bucket';
    my $request = $self->{s3}->_make_request('GET', $ob->_uri($key), {});
    return $self->{s3}->_do_http($request);
}

sub put_object {
    my ($self, $bucket, $key, $content, $opt) = @_;
    my $ob = $self->{s3}->bucket($bucket) or die 'cannot get bucket';
    return $ob->add_key($key, $content, $opt);
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








