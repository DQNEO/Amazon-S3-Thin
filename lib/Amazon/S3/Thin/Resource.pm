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

sub _composer_url {
    my $self = shift;
    my $protocol = shift;
    my $host = shift;
    my $path = shift;

    return "$protocol://$host/$path",
}

sub to_path_style_url {
    my $self = shift;
    my $protocol = shift;
    my $region = shift;
    return $self->_composer_url(
        $protocol,
        $self->_region_specific_host($region),
        $self->{bucket} . '/' . $self->key_and_query
    );
}

sub _region_specific_host {
    my $self = shift;
    my $region = shift;

    if ($region eq 'us-east-1') {
        return 's3.amazonaws.com';
    }

    return sprintf('s3.%s.amazonaws.com', $region); # 's3.eu-west-1.amazonaws.com'
}


# to keep B.C. for old implementation in case region is not given
sub to_url_without_region {
    my $self = shift;
    my $protocol = shift;
    my $main_host = shift;

    my $url;

    my $bucket = $self->{bucket};
    if ($self->_is_dns_bucket($self->{bucket})) {
        # vhost style
        $url = $self->_composer_url($protocol, $bucket . $main_host, $self->key_and_query);
    } else {
        # path style
        $url = $self->_composer_url($protocol, $main_host, $self->{bucket} . "/" . $self->key_and_query);
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


sub key {
    my $self = shift;

    my $key;
    if ($self->{key}) {
        $key = $self->urlencode($self->{key}, 1);
    } else {
        $key = '';
    }
    return $key;
}

sub add_query {
    my $self = shift;

    my $add_query;
    if ($self->{query_string}) {
        $add_query = '?' . $self->{query_string};
    } else {
        $add_query = '';
    }
    return $add_query;
}

sub key_and_query {
    my $self = shift;
    return $self->key . $self->add_query;
}

sub urlencode {
    my ($self, $unencoded, $allow_slash) = @_;
    my $allowed = 'A-Za-z0-9_\-\.';
    $allowed = "$allowed/" if $allow_slash;
    return uri_escape_utf8($unencoded, "^$allowed");
}

1;
