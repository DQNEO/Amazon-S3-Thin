package Amazon::S3::Thin::SignerV2;
use strict;
use warnings;
use Digest::HMAC_SHA1;
use MIME::Base64 ();

my $AMAZON_HEADER_PREFIX = 'x-amz-';

sub new {
    my ($class, $secret) = @_;
    my $self = {secret => $secret};
    bless $self, $class;
}

# generate a canonical string for the given parameters.  expires is optional and is
# only used by query string authentication.
sub calculate_signature {
    my ($self, $method, $path, $headers, $expires) = @_;

    my %interesting_headers = ();
    while (my ($key, $value) = each %$headers) {
        my $lk = lc $key;
        if (   $lk eq 'content-md5'
            or $lk eq 'content-type'
            or $lk eq 'date'
            or $lk =~ /^$AMAZON_HEADER_PREFIX/)
        {
            $interesting_headers{$lk} = $self->_trim($value);
        }
    }

    # these keys get empty strings if they don't exist
    $interesting_headers{'content-type'} ||= '';
    $interesting_headers{'content-md5'}  ||= '';

    # just in case someone used this.  it's not necessary in this lib.
    $interesting_headers{'date'} = ''
      if $interesting_headers{'x-amz-date'};

    # if you're using expires for query string auth, then it trumps date
    # (and x-amz-date)
    $interesting_headers{'date'} = $expires if $expires;

    my $string_to_sign = "$method\n";
    foreach my $key (sort keys %interesting_headers) {
        if ($key =~ /^$AMAZON_HEADER_PREFIX/) {
            $string_to_sign .= "$key:$interesting_headers{$key}\n";
        }
        else {
            $string_to_sign .= "$interesting_headers{$key}\n";
        }
    }

    # don't include anything after the first ? in the resource...
    $path =~ /^([^?]*)/;
    $string_to_sign .= "/$1";

    # ...unless there is an acl or torrent parameter
    if ($path =~ /[&?]acl($|=|&)/) {
        $string_to_sign .= '?acl';
    }
    elsif ($path =~ /[&?]torrent($|=|&)/) {
        $string_to_sign .= '?torrent';
    }
    elsif ($path =~ /[&?]location($|=|&)/) {
        $string_to_sign .= '?location';
    }

    my $hmac = Digest::HMAC_SHA1->new($self->{secret});
    $hmac->add($string_to_sign);
    my $signature =  MIME::Base64::encode_base64($hmac->digest, '');
}

sub _trim {
    my ($self, $value) = @_;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

1;
