#!/usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use Amazon::S3::Thin;
use Test::More;

my $arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    signature_version => 2,
};

$arg->{ua} = MockUA->new;
my $client = Amazon::S3::Thin->new($arg);

my $bucket = "tmpfoobar";
my $key =  "dir/private.txt";

my $res = $client->get_object($bucket, $key);
my $req = $res->request;

diag "test request with sigv2 and region specified";
is $req->method, "GET";
is $req->uri, "http://tmpfoobar.s3.amazonaws.com/dir/private.txt";

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
