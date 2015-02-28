#!/usr/bin/env perl
use strict;
use warnings;
use Config::Tiny;
use Data::Dumper;
use Amazon::S3::Thin;
use Test::More;

my $config_file = $ENV{HOME} . "/.aws/credentials";

my $crd = Config::Tiny->read($config_file)->{dqneo};

my $arg = $crd;
my $client = Amazon::S3::Thin->new($arg);

my $bucket = "tmpdqneo";
my $key =  "dir/s3test.txt";
my $body = "hello amazon s3";

# 0. HEAD to check existance
# 1. DELETE
# 2. PUT to create
# 3. GET
# 4. PUT to update
# 5. DELETE
my $res;
my $req;
diag "DELETE request";
$res =  $client->delete_object($bucket, $key);
$req = $res->request;
ok $res->is_success, "is_success";
is $req->method, "DELETE";
is $req->content, '';
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt";


diag "GET request";
$res = $client->get_object($bucket, $key);
$req = $res->request;
ok !$res->is_success, "is not success";
is $res->code, 404;
is $req->method, "GET";
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt";

diag "PUT request";
$res = $client->put_object($bucket, $key, $body);
ok $res->is_success, "is_success";
$req =  $res->request;
is $req->method, "PUT";
is $req->content, $body;
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt";

diag "COPY request";
my $key2 = $key . "_copied";
$res = $client->copy_object($bucket, $key, $bucket, $key2);
ok $res->is_success, "is_success";
$req =  $res->request;
is $req->method, "PUT";


diag "GET request";
$res = $client->get_object($bucket, $key2);
ok $res->is_success, "is_success";
$req = $res->request;

is $req->method, "GET";
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt_copied";

diag "DELETE request";
$res =  $client->delete_object($bucket, $key);
ok $res->is_success, "is_success";

$res =  $client->delete_object($bucket, $key2);
ok $res->is_success, "is_success";

done_testing;

;
