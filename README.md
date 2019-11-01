[![Build Status](https://travis-ci.org/DQNEO/Amazon-S3-Thin.svg?branch=master)](https://travis-ci.org/DQNEO/Amazon-S3-Thin)
# NAME

Amazon::S3::Thin - A thin, lightweight, low-level Amazon S3 client

# SYNOPSIS

    use Amazon::S3::Thin;

    my $s3client = Amazon::S3::Thin->new({
          aws_access_key_id     => $aws_access_key_id,
          aws_secret_access_key => $aws_secret_access_key,
          aws_session_token     => $aws_session_token, # optional
          region                => $region, # e.g. 'ap-northeast-1'
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

    It returns an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object so you can easily inspect
    what's happening inside, and can handle errors as you like.

- Low Dependency

    It does not require any XML::\* modules, so installation is easy;

- Low Learning Cost

    The interfaces are designed to follow S3 official REST APIs.
    So it is easy to learn.

## Comparison to precedent modules

There are already some useful modules like [Amazon::S3](https://metacpan.org/pod/Amazon::S3), [Net::Amazon::S3](https://metacpan.org/pod/Net::Amazon::S3)
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

- `aws_access_key_id` (**REQUIRED**) - an access key id
of your credentials.
- `aws_secret_access_key` (**REQUIRED**) - an secret access key
 of your credentials.
- `region` - (**REQUIRED**) region of your buckets you access- (currently used only when signature version is 4)
- `secure` - whether to use https or not. Default is 0 (http).
- `ua` - a user agent object, compatible with LWP::UserAgent.
Default is an instance of [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent).
- `signature_version` - AWS signature version to use. Supported values
are 2 and 4. Default is 4.
- `debug` - debug option. Default is 0 (false). 
If set 1, contents of HTTP request and response are shown on stderr

# ACCESSORS

The following accessors are provided. You can use them to get/set your
object's attributes.

## secure

Whether to use https (1) or http (0) when connecting to S3.

## ua

The user agent used internally to perform requests and return responses.
If you set this attribute, please make sure you do so with an object
compatible with [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent) (i.e. providing the same interface).

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

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request. Use the `content()`
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

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request. Use the `header()`
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

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

The DELETE operation removes the null version (if there is one) of an object
and inserts a delete marker, which becomes the current version of the
object. If there isn't a null version, Amazon S3 does not remove any objects.

Use the response object to see if it succeeded or not.

For more information, please refer to
[Amazon's documentation for DELETE](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectDELETE.html).

## copy\_object( $src\_bucket, $src\_key, $dst\_bucket, $dst\_key \[, $headers\] )

**Arguments**: a list with source (bucket, key) and destination (bucket, key), hashref with extra header information (**optional**).

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

This method is a variation of the PUT operation as described by
Amazon's S3 API. It creates a copy of an object that is already stored
in Amazon S3. This "PUT copy" operation is the same as performing a GET
from the old bucket/key and then a PUT to the new bucket/key.

For more information, please refer to
[Amazon's documentation for COPY](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectCOPY.html).

## put\_object( $bucket, $key, $content \[, $headers\] )

**Arguments**:

- 1. bucket - a string with the destination bucket
- 2. key - a string with the destination key
- 3. content - a string with the content to be uploaded
- 4. headers (**optional**) - hashref with extra header information

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

The PUT operation adds an object to a bucket. Amazon S3 never adds partial
objects; if you receive a success response, Amazon S3 added the entire
object to the bucket.

For more information, please refer to
[Amazon's documentation for PUT](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html).

## delete\_multiple\_objects( $bucket, @keys )

**Arguments**: a string with the bucket name, and an array with all the keys
to be deleted.

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

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

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request. Use the `content()`
method on the returned object to read the contents:

This method returns some or all (up to 1000) of the objects in a bucket. Note
that the response might contain fewer keys but will never contain more.
If there are additional keys that satisfy the search criteria but were not
returned because the limit (either 1000 or max-keys) was exceeded, the
response will contain `<IsTruncated>true</IsTruncated>`. To return the
additional keys, see `marker` above.

For more information, please refer to
[Amazon's documentation for REST Bucket GET](https://metacpan.org/pod/&#x20;http:#docs.aws.amazon.com-AmazonS3-latest-API-RESTBucketGET.html).

# TODO

- lots of APIs are not implemented yet.
- Supports both of path\_style and virtual hosted style URL.

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

[Amazon::S3](https://metacpan.org/pod/Amazon::S3), [https://github.com/tima/perl-amazon-s3](https://github.com/tima/perl-amazon-s3)

[Net::Amazon::S3](https://metacpan.org/pod/Net::Amazon::S3)

[Amazon S3 API Reference : REST API](http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html)

[Amazon S3 API Reference : List of Error Codes](http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList)
