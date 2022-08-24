use strict;
use warnings;
use Amazon::S3::Thin;
use Test::More;

my %crd = (
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    );

{
    diag "lack of credientials";
    eval {
        my $s3client = Amazon::S3::Thin->new({});
    };
    ok $@, 'raised No aws_access_key_id exception';
    eval {
        my $s3client = Amazon::S3::Thin->new({
            aws_access_key_id     => "dummy",
        });
    };
    ok $@, 'raised No aws_secret_access_key exception';
}

{
    diag "test new v2";
    my $arg = +{
        %crd,
        signature_version => 2,
    };
    my $s3client = Amazon::S3::Thin->new($arg);
    isa_ok($s3client->{signer}, 'Amazon::S3::Thin::Signer::V2', 'new v2');
}

{
    diag "test new v4";
    my $arg = +{
        %crd,
        signature_version => 4,
        region => 'ap-northeast-1',
    };
    my $s3client = Amazon::S3::Thin->new($arg);
    isa_ok($s3client->{signer}, 'Amazon::S3::Thin::Signer::V4', 'new v4');
}

{
    diag "test from_ecs_container";

    local $ENV{AWS_CONTAINER_CREDENTIALS_RELATIVE_URI} = '/foobar';

    my $arg = +{
        credential_provider => 'ecs_container',
        region => 'ap-northeast-1',
        ua => MockUA->new,
    };
    my $s3client = Amazon::S3::Thin->new($arg);
    isa_ok($s3client->{signer}, 'Amazon::S3::Thin::Signer::V4', 'new v4');

    package MockUA;
    sub new { bless {}, shift; }
    sub get { return MockResponse->new; };

    package MockResponse;
    sub new { bless {}, shift; }
    sub is_success { !!1; }
    sub decoded_content { '{"AccessKeyId": "Key", "SecretAccessKey": "Secret", "Token": "Token"}'; }
}

BEGIN {
    $ENV{AWS_ACCESS_KEY_ID} = 'dummy';
    $ENV{AWS_SECRET_ACCESS_KEY} = 'dummy';
}
{
    diag "test from_env";
    my $arg = +{
        region => 'ap-northeast-1',
        credential_provider => 'env'
    };
    my $s3client = Amazon::S3::Thin->new($arg);
    isa_ok($s3client->{signer}, 'Amazon::S3::Thin::Signer::V4', 'new v4');
}

done_testing;
