package Amazon::S3::Thin::Resource;
use strict;
use warnings;
use URI::Escape qw(uri_escape_utf8);

sub new {
    my $class = shift;
    my $bucket = shift;
    my $key = shift;

    my $self = {
        bucket => $bucket,
        key => $key,
    };
    bless $self, $class;
}

sub key {
    my $self = shift;
    return $self->{key};
}

sub bucket {
    my $self = shift;
    return $self->{bucket};
}

sub to_uri {
    my $self = shift;
    return ($self->key)
      ? $self->bucket . "/" . $self->urlencode($self->key, 1)
      : $self->bucket . "/";
}

sub urlencode {
    my ($self, $unencoded, $allow_slash) = @_;
    my $allowed = 'A-Za-z0-9_\-\.';
    $allowed = "$allowed/" if $allow_slash;
    return uri_escape_utf8($unencoded, "^$allowed");
}

1;
