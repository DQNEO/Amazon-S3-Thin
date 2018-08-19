use strict;
use warnings;
use Amazon::S3::Thin;
use Test::More;

my %crd = (
    aws_access_key_id     => "dummy",
    aws_secret_access_key => "dummy",
    'region' => 'ap-northeast-1',
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

diag "test debug()";
{
    $arg = +{
        %crd,
        debug => 1,
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->debug() , 1;

    $arg = +{
        %crd
    };

    $client = Amazon::S3::Thin->new($arg);

    is $client->debug() , 0;

    $client->debug(1);
    is $client->debug() , 1;
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
