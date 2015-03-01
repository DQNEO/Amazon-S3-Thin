use strict;
use warnings;
use Amazon::S3::Thin;
use Test::More;

my %crd = (
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    );

my $arg;
my $client;

diag "test secure()";
{
    $arg = +{
        %crd,
        secure => 1,
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->secure() , 1;

    $arg = +{
        %crd
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->secure() , 0;
}


done_testing;
