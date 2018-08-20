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

sub to_path_style_url {
    my $self = shift;
    my $protocol = shift;
    my $region = shift;
    return sprintf('%s://%s/%s',
                   $protocol,
                   $self->_region_specific_host($region),
                   $self->_to_path);
}

sub _region_specific_host {
    my $self = shift;
    my $region = shift;

    if ($region eq 'us-east-1') {
        return 's3.amazonaws.com';
    }

    return sprintf('s3.%s.amazonaws.com', $region); # 's3.eu-west-1.amazonaws.com'
}


sub to_vhost_style_url {
    my $self = shift;
    my $protocol = shift;
    my $host = shift;

    my $path = $self->_to_path;
    my $url;

    if ($path =~ m{^([^/?]+)(.*)} && $self->_is_dns_bucket($1)) {
        $url = "$protocol://$1.$host$2";
    } else {
        $url = "$protocol://$host/$path";
    }
    return $url;
}

# if a given bucket name can be safely used as a DNS name.
sub _is_dns_bucket {
    my ($self, $bucketname) = @_;

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


sub _to_path {
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
