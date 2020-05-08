#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use Amazon::S3::Thin;
use Test::More;

my $arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    region => 'ap-north-east-1',
};

$arg->{ua} = MockUA->new;
my $client = Amazon::S3::Thin->new($arg);

my $bucket = "tmpfoobar";
my $key =  "dir/private.txt";
my $body = "hello world";

my $res1 = $client->put_object($bucket, $key, $body);

my $res2 = $client->get_object($bucket, $key);

my $res3 = $client->head_object($bucket, $key);

my $req1 = $res1->request;
my $req2 = $res2->request;
my $req3 = $res3->request;

diag "test PUT request";
is $req1->method, "PUT";
is $req1->content, $body;
is $req1->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/dir/private.txt";

diag "test GET request";
is $req2->method, "GET";
is $req2->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/dir/private.txt";

diag "test HEAD request";
is $req3->method, "HEAD";
is $req3->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/dir/private.txt";

diag "test GET request for list_objects";
my $res4 = $client->list_objects($bucket, {prefix => "12012", delimiter => "/"});
my $req4 = $res4->request;
is $req4->method, "GET";
is $req4->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/?delimiter=%2F&prefix=12012";

diag "test POST for delete_multiple_objects";
my $res5 = $client->delete_multiple_objects( $bucket, 'key/one.txt', 'key/two.png' );
my $req5 = $res5->request;
is $req5->method, "POST";
is $req5->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/?delete=";
is $req5->header('Content-MD5'), 'pjGVehBgNtca8xN21pLCCA==';

diag "test GET request with headers";
my $res6 = $client->get_object($bucket, $key, {"X-Test-Header" => "Foo"});
my $req6 = $res6->request;
is $req6->method, "GET";
is $req6->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/dir/private.txt";
is $req6->header("X-Test-Header"), "Foo";

diag "test PUT request (copy) with headers";
my $res7 = $client->copy_object($bucket, $key, $bucket, "copied.txt", {"x-amz-acl" => "public-read"});
my $req7 = $res7->request;
is $req7->method, "PUT";
is $req7->uri, "http://s3.ap-north-east-1.amazonaws.com/tmpfoobar/copied.txt";
is $req7->header("x-amz-copy-source"), "tmpfoobar/dir/private.txt";
is $req7->header("x-amz-acl"), "public-read";

done_testing;

package MockUA;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub request {
    my $self = shift;
    my $request = shift;
    return MockResponse->new({request =>$request});
}

package MockResponse;

sub new {
    my ($class, $self) = @_;
    bless $self, $class;
}

sub request {
    my $self = shift;
    return $self->{request};
}

sub code {
    my $self = shift;
    return 200;
}

sub content {
    my $self = shift;
    return <<'XML';
<CopyObjectResult>
    <LastModified>2009-10-28T22:32:00</LastModified>
    <ETag>"9b2cf535f27731c974343645a3985328"</ETag>
<CopyObjectResult>
XML
}

;
