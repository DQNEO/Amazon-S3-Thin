#!/usr/bin/env perl
use strict;
use warnings;
use Amazon::S3::Thin;
use HTTP::Response;
use Test::More;

my $arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    region => 'ap-north-east-1',
};

my $mock = MockUA->new;

$arg->{ua} = $mock;
my $client = Amazon::S3::Thin->new($arg);

my $bucket = "tmpfoobar";
my $key =  "dir/private.txt";

diag "test PUT request (copy) ";
$mock->response(HTTP::Response->new(200));
my $res1 = $client->copy_object($bucket, $key, $bucket, "copied.txt");
is $res1->code, 500;

diag "test PUT request (copy) with headers";
$mock->response(HTTP::Response->new(200, <<'XML'));
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>InternalError</Code>
  <Message>...</Message>
  <Resource>...</Resource>
  <RequestId>...</RequestId>
</Error>
XML
my $res2 = $client->copy_object($bucket, $key, $bucket, "copied.txt");
is $res2->code, 500;

done_testing;

package MockUA;

sub new {
    my $class = shift;
    bless {}, $class;
}

sub request {
    my $self = shift;
    my $request = shift;
    my $response = $self->response;
    $response->request($request);
    return $response;
}

sub response {
    my $self = shift;
    if (@_) {
        $self->{response} = shift;
    }
    return $self->{response};
}

package MockResponse;

sub new {
    my ($class) = @_;
    bless {}, $class;
}

sub request {
    my $self = shift;
    if (@_) {
        $self->{request} = shift;
    }
    return $self->{request};
}

sub code {
    my $self = shift;
    if (@_) {
        $self->{code} = shift;
    }
    return $self->{code};
}

sub content {
    my $self = shift;
    if (@_) {
        $self->{content} = shift;
    }
    return $self->{content};
}

;
