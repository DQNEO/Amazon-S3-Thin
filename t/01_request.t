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
$arg->{ua} = MyUA->new;
my $client = Amazon::S3::Simple->new($arg);

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

diag "test GET request";
is $req2->method, "GET";

done_testing;

package MyUA;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub request {
    my $self = shift;
    my $request = shift;
    return MyResponse->new({request =>$request});
}

package MyResponse;
use base qw(Class::Accessor::Fast);

sub request {
    my $self = shift;
    return $self->{request};
}

;
