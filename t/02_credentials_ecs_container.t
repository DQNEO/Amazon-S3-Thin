use strict;
use warnings;
use Amazon::S3::Thin::Credentials;
use Test::More;

my $arg = +{
    credential_provider => 'ecs_container',
    region              => 'ap-northeast-1',
};

{
    diag "retrieve credentials from the ECS task role";

    local $ENV{AWS_CONTAINER_CREDENTIALS_RELATIVE_URI} = '/foobar';

    my $ua = MockUA->new;
    my $credentials = Amazon::S3::Thin::Credentials->from_ecs_container(+{ ua => $ua });

    is_deeply $ua->requests, [
        {
            method  => 'GET',
            uri     => 'http://169.254.170.2/foobar',
        },
    ];

    is $credentials->access_key_id, 'DUMMY-ACCESS-KEY';
    is $credentials->secret_access_key, 'DUMMY-SECRET-ACCESS-KEY';
    is $credentials->session_token, 'DUMMY-TOKEN';
}

{
    diag "AWS_CONTAINER_CREDENTIALS_RELATIVE_URI is not set";

    my $ua = MockUA->new;

    eval {
        my $credentials = Amazon::S3::Thin::Credentials->from_ecs_container(+{ ua => $ua });
    };

    like $@, qr/The environment variable AWS_CONTAINER_CREDENTIALS_RELATIVE_URI is not set/;
}

{
    diag "request failed";

    local $ENV{AWS_CONTAINER_CREDENTIALS_RELATIVE_URI} = '/internal_server_error';

    my $ua = MockUA->new;
    eval {
        my $credentials = Amazon::S3::Thin::Credentials->from_ecs_container(+{ ua => $ua });
    };

    like $@, qr/Error retrieving container credentials/;
}

{
    diag "returned content is not JSON";

    local $ENV{AWS_CONTAINER_CREDENTIALS_RELATIVE_URI} = '/not_json';

    my $ua = MockUA->new;
    eval {
        my $credentials = Amazon::S3::Thin::Credentials->from_ecs_container(+{ ua => $ua });
    };

    like $@, qr/Invalid data returned: /;
}

done_testing;

package MockUA;

sub new {
    my $class = shift;
    bless { requests => [] }, $class;
}

sub get {
    my ($self, $uri) = @_;
    
    my $request = {
        method  => 'GET',
        uri     => $uri,
    };
    
    push @{$self->{requests}}, $request;
    
    return MockResponse->new({ request => $request });
}

sub requests {
    my $self = shift;
    
    $self->{requests};
}

package MockResponse;

sub new {
    my ($class, $self) = @_;
    bless $self, $class;
}

sub is_success {
    my $self = shift;
    
    my $latest_uri = $self->{request}->{uri};
    
    return $latest_uri !~ qr{/internal_server_error$};
}

sub decoded_content {
    my $self = shift;
    
    my $latest_uri = $self->{request}->{uri};
    
    if ($latest_uri =~ qr{/foobar$}) {
        return <<'JSON';
{
  "AccessKeyId" : "DUMMY-ACCESS-KEY",
  "Expiration" : "2022-08-01T12:00:00Z",
  "RoleArn" : "DUMMY-TASK-ROLE-ARN",
  "SecretAccessKey" : "DUMMY-SECRET-ACCESS-KEY",
  "Token" : "DUMMY-TOKEN"
}
JSON
    } elsif ($latest_uri =~ qr{/internal_server_error$}) {
        return '';
    } else {
        return 'not json';
    }
}
