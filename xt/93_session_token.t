use strict;
use warnings;
use Test::More;
use Config::Tiny;
use File::Basename qw(basename);
use LWP::UserAgent;

use Amazon::S3::Thin;

=head1 HOW TO TEST

    PROFILE=__PUT_HERE_YOUR_PROFILE__
    ROLE_ARN=__PUT_HERE_YOUR_ROLE_ARN__

    TEMP_SESSION=$(aws --profile ${PROFILE} sts assume-role --role-arn ${ROLE_ARN} --role-session-name s3thin-test-session)
    export AWS_ACCESS_KEY_ID=$(echo ${TEMP_SESSION} | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo ${TEMP_SESSION} | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo ${TEMP_SESSION} | jq -r '.Credentials.SessionToken')

=cut

if (!$ENV{EXTENDED_TESTING}) {
    plan skip_all => 'Skip functional test because it would call S3 APIs and charge real money. $ENV{EXTENDED_TESTING} is not set.';
}

unless ($ENV{AWS_ACCESS_KEY_ID} && $ENV{AWS_SECRET_ACCESS_KEY} && $ENV{AWS_SESSION_TOKEN}) {
    die "AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN are not set";
}

my $debug = 1;
my $use_https = 1;

my $bucket = $ENV{TEST_S3THIN_BUCKET} || 'dqneo-private-test';

my $arg = {
    aws_access_key_id     => $ENV{AWS_ACCESS_KEY_ID},
    aws_secret_access_key => $ENV{AWS_SECRET_ACCESS_KEY},
    aws_session_token     => $ENV{AWS_SESSION_TOKEN},
    region                => 'ap-northeast-1',
    secure                => $use_https,
    debug                 => $debug,
};
my $client = Amazon::S3::Thin->new($arg);

subtest 'put and get and delete object' => sub {
    my $key =  "dir/s3test.txt";
    my $body = "hello amazon s3";

    my $res;
    $res = $client->put_object($bucket, $key, $body);
    is $res->code, 200;

    $res = $client->get_object($bucket, $key);
    is $res->code, 200;
    is $res->content, $body;

    $res =  $client->delete_object($bucket, $key);
    is $res->code, 204;
};

subtest 'generate_presigned_post' => sub {
    my $ua = LWP::UserAgent->new;

    my $key = 'upload.txt';
    my $presigned = $client->generate_presigned_post($bucket, $key, [], []);

    my $res = $ua->post(
        $presigned->{url},
        Content_Type => 'multipart/form-data',
        Content      => [
            @{$presigned->{fields}},
            file => ['xt/upload.txt'],
        ],
    );
    is $res->code, 204;

    $res = $client->get_object($bucket, $key);
    is $res->code, 200;

    $res = $client->delete_object($bucket, $key);
    is $res->code, 204;
};

done_testing;
