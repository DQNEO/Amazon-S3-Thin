#!/usr/bin/env perl
use strict;
use warnings;
use Config::Tiny;
use Data::Dumper;
use Amazon::S3::Simple;
use Test::More;

my $config_file = $ENV{HOME} . "/.aws/credentials";

my $crd = Config::Tiny->read($config_file)->{dqneo};

my $arg = $crd;
my $client = Amazon::S3::Simple->new($arg);

my $bucket = "tmpdqneo";
my $key =  "dir/s3test.txt";
my $body = "hello amazon s3";

# 0. HEAD to check existance
# 1. DELETE
# 2. PUT to create
# 3. GET
# 4. PUT to update
# 5. DELETE
diag "test PUT request";
my $res;
my $req;
$res =  $client->delete_object($bucket, $key);
$req = $res->request;
ok $res->is_success, "is_success";
is $req->method, "DELETE";
is $req->content, '';
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt";


$res = $client->put_object($bucket, $key, $body);
ok $res->is_success, "is_success";


$req =  $res->request;
diag "test PUT request";
is $req->method, "PUT";
is $req->content, $body;
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt";

$res = $client->get_object($bucket, $key);
ok $res->is_success, "is_success";
$req = $res->request;

diag "test GET request";
is $req->method, "GET";
is $req->uri, "http://tmpdqneo.s3.amazonaws.com/dir%2Fs3test%2Etxt";

done_testing;

;
