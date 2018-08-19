use strict;
use warnings;
use Amazon::S3::Thin;
use Test::More 'no_plan';
use Data::Dumper;

my $debug = 0;

sub test_with_existing_bucket {
    my $crd = shift;
    my $arg = shift;
    diag('Testing with existing resources.');

    # This region is that of the bucket used in this test,
    # because in signature v4 we must know the region of a bucket before accessing it.
    my $region = 'ap-northeast-1';

    my %opt = (
        aws_access_key_id => $crd->{aws_access_key_id},
        aws_secret_access_key => $crd->{aws_secret_access_key},
        secure => 0,
        signature_version => $arg->{signature_version},
        region => $region,
#        use_path_style => $arg->{use_path_style},
        debug => $debug,
    );

    my $s3client = Amazon::S3::Thin->new(\%opt);
    ok $s3client, 'new';

    # These bucket and key suppose to exists beforehand.
    my $bucket = 'dqneo-private-test';
    my $key = 'hello.txt';

    my $response;

    diag('get an existing object in an existing bucket');
    $response = $s3client->get_object($bucket, $key);
    is $response->code , 200;
    is $response->content, "hello world\n";

    diag('list object in an existing bucket');
    $response = $s3client->list_objects($bucket);
    is $response->code , 200;
    like $response->content, qr/hello.txt/;
}

sub test_with_new_bucket {
    my $crd = shift;
    my $arg = shift;
    diag(' region ' . $arg->{region});
    my %opt = (
        aws_access_key_id => $crd->{aws_access_key_id},
        aws_secret_access_key => $crd->{aws_secret_access_key},
        secure => 0,
        signature_version => $arg->{signature_version},
        region => $arg->{region},
#        use_path_style => $arg->{use_path_style},
        debug => $debug,
    );
    my $s3client = Amazon::S3::Thin->new(\%opt);
    my $bucket = 's3thin-' . $arg->{region} . $arg->{signature_version}  . time();
    my $response;
    $response = $s3client->put_bucket($bucket);
    is $response->code , 200 , 'create new bucket';

    my $key = 'hobbit.txt';
    my $content = "In a hole in the ground there lived a hobbit.\n";
    $response = $s3client->put_object($bucket, $key, $content);
    is $response->code , 200, 'create new object';
    
    $response = $s3client->list_objects($bucket);
    is $response->code , 200, 'list created objects';
    like $response->content, qr/$key/;

    $response = $s3client->get_object($bucket, $key);
    is $response->code , 200, 'get created object';
    is $response->content, $content;

    $response = $s3client->delete_object($bucket, $key);
    is $response->code , 204 , 'delete created object';
    
    $response = $s3client->delete_bucket($bucket);
    is $response->code , 204, 'delete created bucket';
}

SKIP : {
    if ($ENV{USER} ne 'DQNEO') {
        skip "functional test because it would call S3 APIs and charge real money.";
    }

    use Config::Tiny;

    # https://docs.aws.amazon.com/cli/latest/userguide/cli-config-files.html
    my $profile = 's3thin';
    my $cred_file = $ENV{HOME} . "/.aws/credentials";
    my $crd = Config::Tiny->read($cred_file)->{$profile};

    my $sigver;
    test_with_existing_bucket($crd, {signature_version => 4});
    test_with_existing_bucket($crd, {signature_version => 2});

    diag('Testing with new resources.');
    my @regions = ('ap-northeast-1', 'us-west-1', 'eu-west-1', 'us-east-1');
    for my $region (@regions) {
        test_with_new_bucket($crd, {signature_version => 4, region =>$region});
        test_with_new_bucket($crd, {signature_version => 2, region =>$region});
    }
}

