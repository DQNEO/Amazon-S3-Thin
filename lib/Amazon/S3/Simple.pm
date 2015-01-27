package Amazon::S3::Simple;
use strict;
use warnings;
use HTTP::Response;

use Amazon::S3;
use Amazon::S3::Bucket;


use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(
    qw(aws_access_key_id aws_secret_access_key account)
);

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    $self->{s3} = Amazon::S3->new(@_);
    return $self;
}

sub get_object {
    my ($self, $bucket, $key) = @_;
    my $request = $self->{s3}->_make_request('GET', $self->_uri($bucket, $key), {});
    return $self->{s3}->_do_http($request);
}

sub put_object {
    my ($self, $bucket, $key, $content, $opt) = @_;
    return $self->add_key($bucket, $key, $content, $opt);
}

sub _uri {
    my ($self, $bucket, $key) = @_;
    return ($key)
      ? $bucket . "/" . $self->{s3}->_urlencode($key)
      : $bucket . "/";
}

use Carp;

sub add_key {
    my ($self, $bucket, $key, $value, $conf) = @_;
    croak 'must specify key' unless $key && length $key;
    my $s3 = $self->{account} = $self->{s3};
    
    if ($conf->{acl_short}) {
        $self->account->_validate_acl_short($conf->{acl_short});
        $conf->{'x-amz-acl'} = $conf->{acl_short};
        delete $conf->{acl_short};
    }

    if (ref($value) eq 'SCALAR') {
        $conf->{'Content-Length'} ||= -s $$value;
        $value = _content_sub($$value);
    }
    else {
        $conf->{'Content-Length'} ||= length $value;
    }

    # If we're pushing to a bucket that's under DNS flux, we might get a 307
    # Since LWP doesn't support actually waiting for a 100 Continue response,
    # we'll just send a HEAD first to see what's going on

    if (ref($value)) {
        return $self->account->_send_request_expect_nothing_probed('PUT',
            $self->_uri($bucket, $key), $conf, $value);
    }
    else {
        return $self->account->_send_request_expect_nothing('PUT',
            $self->_uri($bucket, $key), $conf, $value);
    }
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








