use strict;
use warnings;
use Test::More;
use Config::Tiny;
use File::Basename qw(basename);
use LWP::UserAgent;

use Amazon::S3::Thin;

if (!$ENV{EXTENDED_TESTING}) {
    plan skip_all => 'Skip functional test because it would call S3 APIs and charge real money. $ENV{EXTENDED_TESTING} is not set.';
}

my $debug = 1;
my $use_https = 1;

my $config_file = $ENV{HOME} . '/.aws/credentials';
my $profile = 's3thin';
my $bucket = $ENV{TEST_S3THIN_BUCKET} || 'dqneo-private-test';
my $filename = 'xt/upload.txt';
my $content = do {
    open my $fh, '<', $filename or die $!;
    local $/; <$fh>;
};

my $crd = Config::Tiny->read($config_file)->{$profile};

my $arg = {
    %$crd,
    region => 'ap-northeast-1',
    secure => $use_https,
    debug => $debug,
};
my $client = Amazon::S3::Thin->new($arg);
my $ua = LWP::UserAgent->new;

sub upload {
    my $presigned = shift;
    return $ua->post(
        $presigned->{url},
        Content_Type => 'multipart/form-data',
        Content      => [
            @{$presigned->{fields}},
            file => [$filename],
        ],
    );
}

subtest 'upload with content-type and metadata' => sub {
    my $key = 'upload.txt';
    my $presigned = $client->generate_presigned_post($bucket, $key, [
        'Content-Type'   => 'image/png',
        'x-amz-meta-foo' => 'bar',
    ], [
        ['starts-with' => '$x-amz-meta-foo', ''],
        ['starts-with' => '$Content-Type', 'image/'],
    ]);

    my $res = upload($presigned);
    is $res->code, 204, 'upload via presigned url';

    $res = $client->get_object($bucket, $key);
    is $res->code, 200, 'get uploaded object';
    is $res->content, $content;
    is $res->header('content-type'), 'image/png';
    is $res->header('x-amz-meta-foo'), 'bar';

    $res = $client->delete_object($bucket, $key);
    is $res->code, 204, 'delete uploaded object';
};

subtest 'upload with filename foo-${filename}' => sub {
    my $presigned = $client->generate_presigned_post($bucket, 'foo-${filename}', [], []);

    my $res = upload($presigned);
    is $res->code, 204, 'upload via presigned url';

    my $key = 'foo-' . basename($filename);
    $res = $client->get_object($bucket, $key);
    is $res->code, 200, 'get uploaded object';
    is $res->content, $content;

    $res = $client->delete_object($bucket, $key);
    is $res->code, 204, 'delete uploaded object';
};

subtest 'allowable size for uploading is restricted' => sub {
    my $key = 'upload.txt';
    my $presigned = $client->generate_presigned_post($bucket, $key, [], [
        # allow a file size from 0 to 1 byte
        ['content-length-range', 0, 1],
    ]);

    my $res = upload($presigned);
    is $res->code, 400, 'too large';

    $res = $client->head_object($bucket, $key);
    ok $res->is_error, 'file is not uploaded';
};

subtest 'upload after the expiration date' => sub {
    my $key = 'upload.txt';
    my $presigned = $client->generate_presigned_post($bucket, $key, [], [], 1);

    diag 'sleep 1 second to expire presigned url...';
    sleep 1;

    my $res = upload($presigned);
    is $res->code, 403, 'expire';

    $res = $client->head_object($bucket, $key);
    ok $res->is_error, 'file is not uploaded';
};

done_testing;

