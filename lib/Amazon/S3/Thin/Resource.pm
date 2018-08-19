package Amazon::S3::Thin::Resource;
use strict;
use warnings;
use URI::Escape qw(uri_escape_utf8);

sub new {
    my $class = shift;
    my $bucket = shift;
    my $key = shift;
    my $query_string = shift;

    my $self = {
        bucket => $bucket,
        key => $key,
        query_string => $query_string,
    };
    bless $self, $class;
}

sub to_uri {
    my $self = shift;
    my $path = ($self->{key})
      ? $self->{bucket} . "/" . $self->urlencode($self->{key}, 1)
      : $self->{bucket} . "/";
    if ($self->{query_string}) {
        $path .= '?' . $self->{query_string};
    }
    return $path;
}

sub urlencode {
    my ($self, $unencoded, $allow_slash) = @_;
    my $allowed = 'A-Za-z0-9_\-\.';
    $allowed = "$allowed/" if $allow_slash;
    return uri_escape_utf8($unencoded, "^$allowed");
}

1;
