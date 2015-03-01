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


my $req1 =  $res1->request;
my $req2 = $res2->request;

diag "test PUT request";
is $req1->method, "PUT";
is $req1->content, $body;
is $req1->uri, "http://tmpfoobar.s3.amazonaws.com/dir%2Fprivate%2Etxt";


diag "test GET request";
is $req2->method, "GET";
is $req2->uri, "http://tmpfoobar.s3.amazonaws.com/dir%2Fprivate%2Etxt";

my $res3 = $client->list_objects($bucket, {prefix => "12012", delimiter => "/"});
my $req3 = $res3->request;
is $req3->method, "GET";
is $req3->uri, "http://tmpfoobar.s3.amazonaws.com/?delimiter=%2F&prefix=12012";

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
