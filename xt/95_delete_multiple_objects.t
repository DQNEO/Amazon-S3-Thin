use strict;
use warnings;
use Test::More;
use Config::Tiny;

use Amazon::S3::Thin;

if (!$ENV{EXTENDED_TESTING}) {
    plan skip_all => 'Skip functional test because it would call S3 APIs and charge real money. $ENV{EXTENDED_TESTING} is not set.';
}

my $debug = 1;
my $use_https = 1;

my $config_file = $ENV{HOME} . '/.aws/credentials';
my $profile = 's3thin';
my $bucket = $ENV{TEST_S3THIN_BUCKET} || 'dqneo-private-test';
my $region = 'ap-northeast-1';
my $host = "s3.$region.amazonaws.com";

my $crd = Config::Tiny->read($config_file)->{$profile};

my $arg = {
    %$crd,
    region => $region,
    secure => $use_https,
    debug  => $debug,
};
my $protocol = $use_https ? 'https' : 'http';
my $client = Amazon::S3::Thin->new($arg);

my $key1 =  "dir/s3test_1.txt";
my $key2 =  "dir/s3test_2.txt";
my $body = "hello amazon s3";

my $res;
my $req;

diag "PUT request";
$res = $client->put_object($bucket, $key1, $body);
ok $res->is_success, "is_success";
$res = $client->put_object($bucket, $key2, $body);
ok $res->is_success, "is_success";

diag "DELETE request";
$res =  $client->delete_multiple_objects($bucket, $key1, $key2);
ok $res->is_success, "is_success";
$req =  $res->request;
is $req->method, "POST";
is $req->content, "<Delete><Quiet>true</Quiet><Object><Key>$key1</Key></Object><Object><Key>$key2</Key></Object></Delete>";
is $req->uri, "$protocol://$host/$bucket/?delete=";

diag "HEAD request";
$res = $client->head_object($bucket, $key1);
ok $res->is_error, "is_error";
$res = $client->head_object($bucket, $key2);
ok $res->is_error, "is_error";

done_testing;
