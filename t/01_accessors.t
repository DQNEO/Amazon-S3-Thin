use strict;
use warnings;
use Amazon::S3::Thin;
use Test::More;

diag "test secure()";

my $arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    secure => 1,
};

my $client = Amazon::S3::Thin->new($arg);

is $client->secure() , 1;

$arg = +{
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    secure => 0,
};

$client = Amazon::S3::Thin->new($arg);

is $client->secure() , 0;


done_testing;
