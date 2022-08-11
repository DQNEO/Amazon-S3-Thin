use strict;
use warnings;
use Amazon::S3::Thin::Credentials;
use Test::More;

my $arg = +{
  credential_provider => 'metadata',
  region              => 'ap-northeast-1',
};

{
  diag "IMDSv1";

  my $ua = MockUA->new;
  my $credentials = Amazon::S3::Thin::Credentials->from_metadata(+{
    %$arg,
    ua      => $ua,
    version => 1,
  });

  is_deeply $ua->requests, [
    {
      method  => 'GET',
      uri     => 'http://169.254.169.254/latest/meta-data/iam/security-credentials',
      headers => {},
    },
    {
      method => 'GET',
      uri     => 'http://169.254.169.254/latest/meta-data/iam/security-credentials/DUMMY-INSTANCE-PROFILE-1',
      headers => {},
    },
  ];

  is $credentials->access_key_id, 'DUMMY-ACCESS-KEY';
  is $credentials->secret_access_key, 'DUMMY-SECRET-ACCESS-KEY';
  is $credentials->session_token, 'DUMMY-TOKEN';
}

{
  diag "IMDSv2";

  my $ua = MockUA->new;
  my $credentials = Amazon::S3::Thin::Credentials->from_metadata(+{
    %$arg,
    ua => $ua,
  });

  is_deeply $ua->requests, [
    {
      method  => 'PUT',
      uri     => 'http://169.254.169.254/latest/api/token',
      headers => { 'X-aws-ec2-metadata-token-ttl-seconds' => 90 },
    },
    {
      method  => 'GET',
      uri     => 'http://169.254.169.254/latest/meta-data/iam/security-credentials',
      headers => { 'X-aws-ec2-metadata-token' => 'DUMMY-METADATA-TOKEN' },
    },
    {
      method => 'GET',
      uri     => 'http://169.254.169.254/latest/meta-data/iam/security-credentials/DUMMY-INSTANCE-PROFILE-1',
      headers => { 'X-aws-ec2-metadata-token' => 'DUMMY-METADATA-TOKEN' },
    },
  ];

  is $credentials->access_key_id, 'DUMMY-ACCESS-KEY';
  is $credentials->secret_access_key, 'DUMMY-SECRET-ACCESS-KEY';
  is $credentials->session_token, 'DUMMY-TOKEN';
}

{
  diag "test when a role name is specified";

  my $ua = MockUA->new;
  my $credentials = Amazon::S3::Thin::Credentials->from_metadata(+{
    %$arg,
    ua      => $ua,
    role    => 'DUMMY-INSTANCE-PROFILE-3',
    version => 1,
  });

  is_deeply $ua->requests, [
    {
      method  => 'GET',
      uri     => 'http://169.254.169.254/latest/meta-data/iam/security-credentials',
      headers => {},
    },
    {
      method => 'GET',
      uri     => 'http://169.254.169.254/latest/meta-data/iam/security-credentials/DUMMY-INSTANCE-PROFILE-3',
      headers => {},
    },
  ];

  is $credentials->access_key_id, 'DUMMY-ACCESS-KEY';
  is $credentials->secret_access_key, 'DUMMY-SECRET-ACCESS-KEY';
  is $credentials->session_token, 'DUMMY-TOKEN';
}

done_testing;

package MockUA;

sub new {
  my $class = shift;
  bless { requests => [], default_headers => {} }, $class;
}

sub get {
  my ($self, $uri, %form) = @_;

  $self->_request('GET', $uri, %form);
}

sub put {
  my ($self, $uri, %form) = @_;

  $self->_request('PUT', $uri, %form);
}

sub _request {
  my ($self, $method, $uri, %form) = @_;

  my $request = {
    method  => $method,
    uri     => $uri,
    headers => { %{$self->{default_headers}}, %form },
  };

  push @{$self->{requests}}, $request;

  return MockResponse->new({ request => $request });
}

sub requests {
  my $self = shift;
  
  $self->{requests};
}

sub default_header {
  my ($self, %headers) = @_;
  $self->{default_headers}->{$_} = $headers{$_} for keys %headers;
}

package MockResponse;

sub new {
  my ($class, $self) = @_;
  bless $self, $class;
}

sub is_success { !!1; }

sub decoded_content {
  my $self = shift;

  my $latest_uri = $self->{request}->{uri};

  if ($latest_uri =~ qr{/latest/api/token$}) {
    return 'DUMMY-METADATA-TOKEN';
  } elsif ($latest_uri =~ qr{/latest/meta-data/iam/security-credentials$}) {
    return <<'TEXT';
DUMMY-INSTANCE-PROFILE-1
DUMMY-INSTANCE-PROFILE-2
DUMMY-INSTANCE-PROFILE-3
TEXT
  } elsif ($latest_uri =~ qr{/latest/meta-data/iam/security-credentials/.+$}) {
    return <<'JSON';
{
  "Code" : "Success",
  "LastUpdated" : "2022-08-01T00:00:00Z",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "DUMMY-ACCESS-KEY",
  "SecretAccessKey" : "DUMMY-SECRET-ACCESS-KEY",
  "Token" : "DUMMY-TOKEN",
  "Expiration" : "2022-08-01T12:00:00Z"
}
JSON
  }
}
