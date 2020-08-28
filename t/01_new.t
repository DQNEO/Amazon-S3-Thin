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
    ok $@, $@;
    eval {
        my $s3client = Amazon::S3::Thin->new({
            aws_access_key_id     => "dummy",
        });
    };
    ok $@, $@;
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
