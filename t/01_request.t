#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use Amazon::S3::Thin;
use Test::More;

my $arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
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
is $req1->uri, "http://tmpfoobar.s3.amazonaws.com/dir%2Fprivate%2Etxt";

diag "test GET request";
is $req2->method, "GET";
is $req2->uri, "http://tmpfoobar.s3.amazonaws.com/dir%2Fprivate%2Etxt";

diag "test HEAD request";
is $req3->method, "HEAD";
is $req3->uri, "http://tmpfoobar.s3.amazonaws.com/dir%2Fprivate%2Etxt";

diag "test GET request for list_objects";
my $res4 = $client->list_objects($bucket, {prefix => "12012", delimiter => "/"});
my $req4 = $res4->request;
is $req4->method, "GET";
is $req4->uri, "http://tmpfoobar.s3.amazonaws.com/?delimiter=%2F&prefix=12012";

diag "test POST for delete_multiple_objects";
my $res5 = $client->delete_multiple_objects( $bucket, 'key/one.txt', 'key/two.png' );
my $req5 = $res5->request;
is $req5->method, "POST";
is $req5->uri, "http://tmpfoobar.s3.amazonaws.com/?delete";
is $req5->header('Content-MD5'), 'pjGVehBgNtca8xN21pLCCA==';

diag "test GET request with headers";
my $res6 = $client->get_object($bucket, $key, {"X-Test-Header" => "Foo"});
my $req6 = $res6->request;
is $req6->method, "GET";
is $req6->uri, "http://tmpfoobar.s3.amazonaws.com/dir%2Fprivate%2Etxt";
is $req6->header("X-Test-Header"), "Foo";

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

;
