package Amazon::S3::Thin::Signer::V2;
use strict;
use warnings;
use Carp;
use Digest::HMAC_SHA1;
use MIME::Base64 ();
use HTTP::Date ();

my $AMAZON_HEADER_PREFIX = 'x-amz-';

# reserved subresources such as acl or torrent
our @ordered_subresources = qw(
        acl delete lifecycle location logging notification partNumber policy
        requestPayment torrent uploadId uploads versionId versioning versions
        website
    );

sub new {
    my ($class, $credentials, $thin) = @_;
    if (ref($credentials) ne 'Amazon::S3::Thin::Credentials') {
        croak "credentials are not given."
    }
    my $self = {
        credentials => $credentials,
        host => $thin->{host},
    };
    bless $self, $class;
}

sub sign
{
  my ($self, $request) = @_;
  $request->header(Date => HTTP::Date::time2str(time)) unless $request->header('Date');
  my $host = $request->uri->host;
  my $bucket = substr($host, 0, length($host) - length($self->{host}) - 1);
  my $path = $bucket . $request->uri->path;
  my $signature = $self->calculate_signature( $request->method, $path, $request->headers );
  $request->header(
    Authorization => sprintf("AWS %s:%s"
      , $self->{credentials}->access_key_id,
      , $signature));
}

# generate a canonical string for the given parameters.  expires is optional and is
# only used by query string authentication.
sub calculate_signature {
    my ($self, $method, $path, $headers, $expires) = @_;

    my $string_to_sign = $self->string_to_sign( $method, $path, $headers, $expires );

    my $hmac = Digest::HMAC_SHA1->new($self->{credentials}->secret_access_key);
    $hmac->add($string_to_sign);
    return MIME::Base64::encode_base64($hmac->digest, '');
}

sub string_to_sign {
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

    # x-amz-date becomes date if it exists
    $interesting_headers{'date'} = delete $interesting_headers{'x-amz-date'}
        if exists $interesting_headers{'x-amz-date'};

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

    $path =~ /^([^?]*)(.*)/;
    $string_to_sign .= "/$1";
    if (! $2) {
        return $string_to_sign;
    }

    my $query_string = $2;

    my %interesting_subresources = map { $_ => '' } @ordered_subresources;

    foreach my $query (split /[&?]/, $query_string) {
        $query =~ /^([^=]+)/;
        if (exists $interesting_subresources{$1}) {
            $interesting_subresources{$1} = $query;
        }
    }
    my $join_char = '?';
    foreach my $name (@ordered_subresources) {
        if ($interesting_subresources{$name}) {
            $string_to_sign .= $join_char . $name;
            $join_char = '&';
        }
    }
    return $string_to_sign;
}

sub _trim {
    my ($self, $value) = @_;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

1;
