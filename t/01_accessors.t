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

diag "test host()";
{
    $arg = +{
        %crd,
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->host() , 's3.amazonaws.com';

    $arg = +{
        %crd,
        host => "www.example.com",
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->host() , "www.example.com";

}

diag "test ua()";
{
    $arg = +{
        %crd,
    };

    $client = Amazon::S3::Thin->new($arg);

    isa_ok $client->ua() , 'LWP::UserAgent';

    $arg = +{
        %crd,
        ua => "foo",
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->ua() , "foo";

}


done_testing;
