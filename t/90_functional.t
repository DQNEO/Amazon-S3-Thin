#!/usr/bin/env perl
use strict;
use warnings;
use Config::Tiny;
use Data::Dumper;
use Amazon::S3::Thin;
use Test::More 'no_plan';

SKIP : {
    
    if ($ENV{USER} ne 'DQNEO') {
        skip "functional test because it would call S3 APIs and charge real money.";
    }

    my $config_file = $ENV{HOME} . "/.aws/credentials";

    my $crd = Config::Tiny->read($config_file)->{default};

    my $arg = $crd;
    $arg->{region} = 'ap-northeast-1';
    my $client = Amazon::S3::Thin->new($arg);

    my $bucket = "dqneo-private-test";
    my $key =  "dir/s3test.txt";
    my $body = "hello amazon s3";

    my $host = 's3.ap-northeast-1.amazonaws.com';
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
    is $res->code, 204;
    is $req->method, "DELETE";
    is $req->content, '';
    is $req->uri, "http://$host/$bucket/dir/s3test.txt";

    diag "HEAD request on non-existing object";
    $res = $client->head_object($bucket, $key);
    $req = $res->request;
    ok !$res->is_success, "is not success";
    is $res->code, 404;
    is $req->method, "HEAD";
    is $req->uri, "http://$host/$bucket/dir/s3test.txt";

    diag "GET request";
    $res = $client->get_object($bucket, $key);
    $req = $res->request;
    ok !$res->is_success, "is not success";
    is $res->code, 404;
    is $req->method, "GET";
    is $req->uri, "http://$host/$bucket/dir/s3test.txt";

    diag "PUT request";
    $res = $client->put_object($bucket, $key, $body);
    ok $res->is_success, "is_success";
    $req =  $res->request;
    is $req->method, "PUT";
    is $req->content, $body;
    is $req->uri, "http://$host/$bucket/dir/s3test.txt";

    diag "HEAD request";
    $res = $client->head_object($bucket, $key);
    ok $res->is_success, "is_success";
    $req =  $res->request;
    is $req->method, "HEAD";
    is $req->content, '';
    is $req->uri, "http://$host/$bucket/dir/s3test.txt";
    like $res->header("x-amz-request-id"), qr/.+/, "has proper headers";

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
    is $req->uri, "http://$host/$bucket/dir/s3test.txt_copied";

    diag "DELETE request";
    $res =  $client->delete_object($bucket, $key);
    ok $res->is_success, "is_success";

    $res =  $client->delete_object($bucket, $key2);
    ok $res->is_success, "is_success";

}
