use strict;
use warnings;
use Test::More;
use Amazon::S3::Thin;
use MIME::Base64 ();
use JSON::PP ();

BEGIN {
    *CORE::GLOBAL::time = sub() { 1572566400 }; # Fri Nov  1 00:00:00 2019
}

my $_JSON;
sub policy { MIME::Base64::encode_base64(($_JSON ||= JSON::PP->new->utf8->canonical)->encode(@_), '') }

my $args = {
    aws_access_key_id     => 'dummy_access_key_id',
    aws_secret_access_key => 'dummy_secret_access_key',
    region                => 'ap-north-east-1',
    ua                    => MockUA->new,
};
my $client = Amazon::S3::Thin->new({%$args});

my $bucket = 'test-bucket';
my $key = 'dir/private.txt';

is_deeply $client->generate_presigned_post($bucket, $key), {
    url    => 'http://s3.ap-north-east-1.amazonaws.com/test-bucket/',
    fields => [
        key                => $key,
        'x-amz-algorithm'  => 'AWS4-HMAC-SHA256',
        'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request',
        'x-amz-date'       => '20191101T000000Z',
        policy             => policy({
            conditions => [
                {bucket             => 'test-bucket'},
                {key                => 'dir/private.txt'},
                {'x-amz-algorithm'  => 'AWS4-HMAC-SHA256'},
                {'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request'},
                {'x-amz-date'       => '20191101T000000Z'},
            ],
            expiration => '2019-11-01T01:00:00Z',
        }),
        'x-amz-signature' => 'ef0b9394345aa20773e07ecdf1f704135a0fd7a5db78e2e5433b7331668f1cc3',
    ],
};

is_deeply $client->generate_presigned_post($bucket, 'foo-${filename}'), {
    url    => 'http://s3.ap-north-east-1.amazonaws.com/test-bucket/',
    fields => [
        key                => 'foo-${filename}',
        'x-amz-algorithm'  => 'AWS4-HMAC-SHA256',
        'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request',
        'x-amz-date'       => '20191101T000000Z',
        policy             => policy({
            conditions => [
                {bucket             => 'test-bucket'},
                ['starts-with'      => '$key', 'foo-'],
                {'x-amz-algorithm'  => 'AWS4-HMAC-SHA256'},
                {'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request'},
                {'x-amz-date'       => '20191101T000000Z'},
            ],
            expiration => '2019-11-01T01:00:00Z',
        }),
        'x-amz-signature' => '28baaf6392b4a747f1e65d9bb33f205342e025bf23f3d7ab37de880828ac0f52',
    ],
}, '${filename} expands starts-with condition';

is_deeply $client->generate_presigned_post($bucket, $key, [
    'Content-Type'   => 'image/png',
    'x-amz-meta-foo' => 'bar',
]), {
    url    => 'http://s3.ap-north-east-1.amazonaws.com/test-bucket/',
    fields => [
        'Content-Type'   => 'image/png',
        'x-amz-meta-foo' => 'bar',
        key                => $key,
        'x-amz-algorithm'  => 'AWS4-HMAC-SHA256',
        'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request',
        'x-amz-date'       => '20191101T000000Z',
        policy             => policy({
            conditions => [
                {bucket             => 'test-bucket'},
                {key                => 'dir/private.txt'},
                {'x-amz-algorithm'  => 'AWS4-HMAC-SHA256'},
                {'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request'},
                {'x-amz-date'       => '20191101T000000Z'},
            ],
            expiration => '2019-11-01T01:00:00Z',
        }),
        'x-amz-signature' => 'ef0b9394345aa20773e07ecdf1f704135a0fd7a5db78e2e5433b7331668f1cc3',
    ],
}, 'passing $fields is prepended to fields';

is_deeply $client->generate_presigned_post($bucket, $key, [], [
    {acl => 'public-read'},
    ['content-length-range' => 1048579, 10485760],
]), {
    url    => 'http://s3.ap-north-east-1.amazonaws.com/test-bucket/',
    fields => [
        key                => $key,
        'x-amz-algorithm'  => 'AWS4-HMAC-SHA256',
        'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request',
        'x-amz-date'       => '20191101T000000Z',
        policy             => policy({
            conditions => [
                {acl => 'public-read'},
                ['content-length-range' => 1048579, 10485760],
                {bucket             => 'test-bucket'},
                {key                => 'dir/private.txt'},
                {'x-amz-algorithm'  => 'AWS4-HMAC-SHA256'},
                {'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request'},
                {'x-amz-date'       => '20191101T000000Z'},
            ],
            expiration => '2019-11-01T01:00:00Z',
        }),
        'x-amz-signature' => 'bde43ca051cb44488f029018910a13e3dfca0d9bbfcc02c19629c17d2626af0d',
    ],
}, 'passing $conditions is prepended to conditions in policy';

is_deeply $client->generate_presigned_post($bucket, $key, [], [], 24 * 60 * 60), {
    url    => 'http://s3.ap-north-east-1.amazonaws.com/test-bucket/',
    fields => [
        key                => $key,
        'x-amz-algorithm'  => 'AWS4-HMAC-SHA256',
        'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request',
        'x-amz-date'       => '20191101T000000Z',
        policy             => policy({
            conditions => [
                {bucket             => 'test-bucket'},
                {key                => 'dir/private.txt'},
                {'x-amz-algorithm'  => 'AWS4-HMAC-SHA256'},
                {'x-amz-credential' => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request'},
                {'x-amz-date'       => '20191101T000000Z'},
            ],
            expiration => '2019-11-02T00:00:00Z',
        }),
        'x-amz-signature' => '2566acd84ef09a390c72c6e966eb7b72fb6e444ac826c81a1b289e23465b5f44',
    ],
}, 'passing $expire is added to expiration in policy';

subtest 'signature v2' => sub {
    eval {
        my $client = Amazon::S3::Thin->new({%$args, signature_version => 2});
        $client->generate_presigned_post($bucket, $key);
    };
    like $@, qr/generate_presigned_post is only supported on signature v4/;
};

subtest 'bucket and key are required' => sub {
    eval {
        $client->generate_presigned_post();
    };
    like $@, qr/must specify bucket/;

    eval {
        $client->generate_presigned_post($bucket);
    };
    like $@, qr/must specify key/;
};

subtest 'session_token' => sub {
    my $client = Amazon::S3::Thin->new({%$args, aws_session_token => 'dummy_session_token'});
    is_deeply $client->generate_presigned_post($bucket, $key), {
        url    => 'http://s3.ap-north-east-1.amazonaws.com/test-bucket/',
        fields => [
            key                    => $key,
            'x-amz-algorithm'      => 'AWS4-HMAC-SHA256',
            'x-amz-credential'     => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request',
            'x-amz-date'           => '20191101T000000Z',
            'x-amz-security-token' => 'dummy_session_token',
            policy                 => policy({
                conditions => [
                    {bucket                 => 'test-bucket'},
                    {key                    => 'dir/private.txt'},
                    {'x-amz-algorithm'      => 'AWS4-HMAC-SHA256'},
                    {'x-amz-credential'     => 'dummy_access_key_id/20191101/ap-north-east-1/s3/aws4_request'},
                    {'x-amz-date'           => '20191101T000000Z'},
                    {'x-amz-security-token' => 'dummy_session_token'},
                ],
                expiration => '2019-11-01T01:00:00Z',
            }),
            'x-amz-signature' => '9b5167f1e201862214be6d26bb02ebd50d6e46d3e93319a6e17988047ab531b5',
        ],
    };
};

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
