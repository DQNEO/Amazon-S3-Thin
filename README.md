[![Actions Status](https://github.com/DQNEO/Amazon-S3-Thin/workflows/test/badge.svg)](https://github.com/DQNEO/Amazon-S3-Thin/actions)
# NAME

Amazon::S3::Thin - A thin, lightweight, low-level Amazon S3 client

# SYNOPSIS

    use Amazon::S3::Thin;

    # Pass in explicit credentials
    my $s3client = Amazon::S3::Thin->new({
          aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
          aws_session_token     => $aws_session_token, # optional
          region                => $region, # e.g. 'ap-northeast-1'
        });

    # Get credentials from environment
    my $s3client = Amazon::S3::Thin->new({region => $region, credential_provider => 'env'});

    # Get credentials from instance metadata
    my $s3client = Amazon::S3::Thin->new({
        region              => $region,
        credential_provider => 'metadata',
        version             => 2,         # optional (default 2)
        role                => 'my-role', # optional
      });

    # Get credentials from ECS task role
    my $s3client = Amazon::S3::Thin->new({
        region              => $region,
        credential_provider => 'ecs_container',
      });

    my $bucket = "mybucket";
    my $key = "dir/file.txt";
    my $response;

    $response = $s3client->put_bucket($bucket);

    $response = $s3client->put_object($bucket, $key, "hello world");

    $response = $s3client->get_object($bucket, $key);
    print $response->content; # => "hello world"

    $response = $s3client->delete_object($bucket, $key);

    $response = $s3client->list_objects(
                                $bucket,
                                {prefix => "foo", delimiter => "/"}
                               );

You can also pass any useragent as you like

    my $s3client = Amazon::S3::Thin->new({
            ...
            ua => $any_LWP_copmatible_useragent,
        });

Signature version 4 is used by default. 
To use signature version 2, add a `signature_version` option:

    my $s3client = Amazon::S3::Thin->new({
            ...
            signature_version     => 2,
        });

# DESCRIPTION

Amazon::S3::Thin is a thin, lightweight, low-level Amazon S3 client.

It's designed for only ONE purpose: Send a request and get a response.

In detail, it offers the following features:

- Low Level

    It returns an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object so you can easily inspect
    what's happening inside, and can handle errors as you like.

- Low Dependency

    It does not require any XML::\* modules, so installation is easy;

- Low Learning Cost

    The interfaces are designed to follow S3 official REST APIs.
    So it is easy to learn.

## Comparison to precedent modules

There are already some useful modules like [Amazon::S3](https://metacpan.org/pod/Amazon%3A%3AS3), [Net::Amazon::S3](https://metacpan.org/pod/Net%3A%3AAmazon%3A%3AS3)
 on CPAN. They provide a "Perlish" interface, which looks pretty
 for Perl programmers, but they also hide low-level behaviors.
For example, the "get\_key" method translate HTTP status 404 into `undef` and
 HTTP 5xx status into exception.

In some situations, it is very important to see the raw HTTP communications.
That's why I made this module.

# CONSTRUCTOR

## new( \\%params )

**Receives:** hashref with options.

**Returns:** Amazon::S3::Thin object

It can receive the following arguments:

- `credential_provider` (**default: credentials**) - specify where to source credentials from. Options are:
    - `credentials` - existing behaviour, pass in credentials via `aws_access_key_id` and `aws_secret_access_key`
    - `env` - fetch credentials from environment variables
    - `metadata` - fetch credentials from EC2 instance metadata service
    - `ecs_container` - fetch credentials from ECS task role
- `region` - (**REQUIRED**) region of your buckets you access- (currently used only when signature version is 4)
- `aws_access_key_id` (**REQUIRED \[provider: credentials\]**) - an access key id
of your credentials.
- `aws_secret_access_key` (**REQUIRED \[provider: credentials\]**) - an secret access key
 of your credentials.
- `version` (**OPTIONAL \[provider: metadata\]**) - version of metadata service to use, either 1 or 2.
[read more](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configuring-instance-metadata-service.html)
- `role` (**OPTIONAL \[provider: metadata\]**) - IAM instance role to use, otherwise the first is selected
- `secure` - whether to use https or not. Default is 0 (http).
- `ua` - a user agent object, compatible with LWP::UserAgent.
Default is an instance of [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent).
- `signature_version` - AWS signature version to use. Supported values
are 2 and 4. Default is 4.
- `debug` - debug option. Default is 0 (false). 
If set 1, contents of HTTP request and response are shown on stderr
- `virtual_host` - whether to use virtual-hosted style request format. Default is 0 (path-style).

# ACCESSORS

The following accessors are provided. You can use them to get/set your
object's attributes.

## secure

Whether to use https (1) or http (0) when connecting to S3.

## ua

The user agent used internally to perform requests and return responses.
If you set this attribute, please make sure you do so with an object
compatible with [LWP::UserAgent](https://metacpan.org/pod/LWP%3A%3AUserAgent) (i.e. providing the same interface).

## debug

Debug option.

# Operations on Buckets

## put\_bucket( $bucket \[, $headers\])

**Arguments**:

- 1. bucket - a string with the bucket
- 2. headers (**optional**) - hashref with extra header information

## delete\_bucket( $bucket \[, $headers\])

**Arguments**:

- 1. bucket - a string with the bucket
- 2. headers (**optional**) - hashref with extra header information

# Operations on Objects

## get\_object( $bucket, $key \[, $headers\] )

**Arguments**:

- 1. bucket - a string with the bucket
- 2. key - a string with the key
- 3. headers (**optional**) - hashref with extra header information

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request. Use the `content()`
method on the returned object to read the contents:

    my $res = $s3->get_object( 'my.bucket', 'my/key.ext' );

    if ($res->is_success) {
        my $content = $res->content;
    }

The GET operation retrieves an object from Amazon S3.

For more information, please refer to
[Amazon's documentation for GET](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectGET.html).

## head\_object( $bucket, $key )

**Arguments**:

- 1. bucket - a string with the bucket
- 2. key - a string with the key

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request. Use the `header()`
method on the returned object to read the metadata:

    my $res = $s3->head_object( 'my.bucket', 'my/key.ext' );

    if ($res->is_success) {
        my $etag = $res->header('etag'); #=> `"fba9dede5f27731c9771645a39863328"`
    }

The HEAD operation retrieves metadata of an object from Amazon S3.

For more information, please refer to
[Amazon's documentation for HEAD](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectHEAD.html).

## delete\_object( $bucket, $key )

**Arguments**: a string with the bucket name, and a string with the key name.

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request.

The DELETE operation removes the null version (if there is one) of an object
and inserts a delete marker, which becomes the current version of the
object. If there isn't a null version, Amazon S3 does not remove any objects.

Use the response object to see if it succeeded or not.

For more information, please refer to
[Amazon's documentation for DELETE](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectDELETE.html).

## copy\_object( $src\_bucket, $src\_key, $dst\_bucket, $dst\_key \[, $headers\] )

**Arguments**: a list with source (bucket, key) and destination (bucket, key), hashref with extra header information (**optional**).

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request.

This method is a variation of the PUT operation as described by
Amazon's S3 API. It creates a copy of an object that is already stored
in Amazon S3. This "PUT copy" operation is the same as performing a GET
from the old bucket/key and then a PUT to the new bucket/key.

Note that the COPY request might return error response in 200 OK, but this method
will determine the error response and rewrite the status code to 500.

For more information, please refer to
[Amazon's documentation for COPY](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectCOPY.html).

## put\_object( $bucket, $key, $content \[, $headers\] )

**Arguments**:

- 1. bucket - a string with the destination bucket
- 2. key - a string with the destination key
- 3. content - a string with the content to be uploaded
- 4. headers (**optional**) - hashref with extra header information

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request.

The PUT operation adds an object to a bucket. Amazon S3 never adds partial
objects; if you receive a success response, Amazon S3 added the entire
object to the bucket.

For more information, please refer to
[Amazon's documentation for PUT](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html).

## delete\_multiple\_objects( $bucket, @keys )

**Arguments**: a string with the bucket name, and an array with all the keys
to be deleted.

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request.

The Multi-Object Delete operation enables you to delete multiple objects
(up to 1000) from a bucket using a single HTTP request. If you know the
object keys that you want to delete, then this operation provides a suitable
alternative to sending individual delete requests with `delete_object()`,
reducing per-request overhead.

For more information, please refer to
[Amazon's documentation for DELETE multiple objects](http://docs.aws.amazon.com/AmazonS3/latest/API/multiobjectdeleteapi.html).

## list\_objects( $bucket \[, \\%options \] )

**Arguments**: a string with the bucket name, and (optionally) a hashref
with any of the following options:

- `prefix` (_string_) - only return keys that begin with the
specified prefix. You can use prefixes to separate a bucket into different
groupings of keys, the same way you'd use a folder in a file system.
- `delimiter` (_string_) - group keys that contain the same string
between the beginning of the key (or after the prefix, if specified) and the
first occurrence of the delimiter.
- `encoding-type` (_string_) - if set to "url", will encode keys
in the response (useful when the XML parser can't work unicode keys).
- `marker` (_string_) - specifies the key to start with when listing
objects. Amazon S3 returns object keys in alphabetical order, starting with
the key right after the marker, in order.
- `max-keys` (_string_) - Sets the maximum number of keys returned
in the response body. You can add this to your request if you want to
retrieve fewer than the default 1000 keys.

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP%3A%3AResponse) object for the request. Use the `content()`
method on the returned object to read the contents:

This method returns some or all (up to 1000) of the objects in a bucket. Note
that the response might contain fewer keys but will never contain more.
If there are additional keys that satisfy the search criteria but were not
returned because the limit (either 1000 or max-keys) was exceeded, the
response will contain `<IsTruncated>true</IsTruncated>`. To return the
additional keys, see `marker` above.

For more information, please refer to
[Amazon's documentation for REST Bucket GET](https://metacpan.org/pod/%20http%3A#docs.aws.amazon.com-AmazonS3-latest-API-RESTBucketGET.html).

## generate\_presigned\_post( $bucket, $key \[, $fields, $conditions, $expires\_in \] )

**Arguments**:

- 1. bucket (_string_) - a string with the destination bucket
- 2. key (_string_) - a string with the destination key
- 3. fields (_arrayref_) - an arrayref of key/value pairs to prefilled form fields to build on top of
- 4. conditions (_arrayref_) - an arrayref of condition (arrayref or hashref) to include in the policy
- 5. expires\_in (_number_) - a number of seconds from the current time before expiring presigned url

**Returns**: a hashref with two elements `url` and `fields`. `url` is the url to post to. `fields` is an arrayref
filled with the form fields and respective values to use when submitting the post. (You must follow the order of `fields`)

This method generates presigned url for uploading a file to Amazon S3 using HTTP POST.
The original implementation from boto3, this was transplanted referencing [S3Client.generate\_presigned\_post()](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html#S3.Client.generate_presigned_post).

Note: this method is supported only signature v4.

This is an example of generating a presigned url and uploading `test.txt` file.
In this case, you can set the object metadata `x-amz-meta-foo` with any value and the uploading size is limited to 1MB.

    my $presigned = $s3->generate_presigned_post('my.bucket', 'my/key.ext', [
        'x-amz-meta-foo' => 'bar',
    ], [
        ['starts-with' => '$x-amz-meta-foo', ''],
        ['content-length-range' => 1, 1024*1024],
    ], 24*60*60);

    my $ua = LWP::UserAgent->new;
    my $res = $ua->post(
        $presigned->{url},
        Content_Type => 'multipart/form-data',
        Content      => [
            @{$presigned->{fields}},
            file => ['test.txt'],
        ],
    );

For more information, please refer to
[Amazon's documentation for Creating a POST Policy](https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-HTTPPOSTConstructPolicy.html).

# TODO

- lots of APIs are not implemented yet.

# REPOSITORY

[https://github.com/DQNEO/Amazon-S3-Thin](https://github.com/DQNEO/Amazon-S3-Thin)

# LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

DQNEO

## THANKS TO

Timothy Appnel
Breno G. de Oliveira

# SEE ALSO

[Amazon::S3](https://metacpan.org/pod/Amazon%3A%3AS3), [https://github.com/tima/perl-amazon-s3](https://github.com/tima/perl-amazon-s3)

[Net::Amazon::S3](https://metacpan.org/pod/Net%3A%3AAmazon%3A%3AS3)

[Amazon S3 API Reference : REST API](http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html)

[Amazon S3 API Reference : List of Error Codes](http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList)
