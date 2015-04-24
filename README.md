[![Build Status](https://travis-ci.org/DQNEO/Amazon-S3-Thin.svg?branch=master)](https://travis-ci.org/DQNEO/Amazon-S3-Thin)
# NAME

Amazon::S3::Thin - A thin, lightweight, low-level Amazon S3 client

# SYNOPSIS

    use Amazon::S3::Thin;

    my $s3client = Amazon::S3::Thin->new(
        {   aws_access_key_id     => $aws_access_key_id,
            aws_secret_access_key => $aws_secret_access_key,
        }
    );

    my $key = "dir/file.txt";
    my $response;
    $response = $s3client->put_object($bucket, $key, "hello world");

    $response = $s3client->get_object($bucket, $key);
    print $response->content; # => "hello world"

    $response = $s3client->delete_object($bucket, $key);

    $response = $s3client->copy_object($src_bucket, $src_key,
                                       $dst_bucket, $dst_key);

    $response = $s3client->list_objects(
                                $bucket,
                                {prefix => "foo", delimter => "/"}
                               );

    $response = $s3client->head_object($bucket, $key);

You can also pass any useragent as you like

    my $s3client = Amazon::S3::Thin->new(
        {   aws_access_key_id     => $aws_access_key_id,
            aws_secret_access_key => $aws_secret_access_key,
            ua                    => $any_LWP_copmatible_useragent,
        }
    );

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
- `secure` - whether to use https or not. Default is 0 (http).
- `host` - the base host to use. Default is '_s3.amazonaws.com_'.
- `ua` - a user agent object, compatible with LWP::UserAgent.
Default is an instance of [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent).

# ACCESSORS

The following accessors are provided. You can use them to get/set your
object's attributes.

## secure

Whether to use https (1) or http (0) when connecting to S3.

## host

The base host to use for connecting to S3.

## ua

The user agent used internally to perform requests and return responses.
If you set this attribute, please make sure you do so with an object
compatible with [LWP::UserAgent](https://metacpan.org/pod/LWP::UserAgent) (i.e. providing the same interface).

# METHODS

## get\_object( $bucket, $key )

**Arguments**: a string with the bucket name, and a string with the key name.

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request. Use the `content()`
method on the returned object to read the contents:

    my $res = $s3->get_object( 'my.bucket', 'my/key.ext' );

    if ($res->is_success) {
        my $content = $res->content;
    }

The GET operation retrieves an object from Amazon S3.

For more information, please refer to
[Amazon's documentation for GET](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectGET.html).

## delete\_object( $bucket, $key )

**Arguments**: a string with the bucket name, and a string with the key name.

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

The DELETE operation removes the null version (if there is one) of an object
and inserts a delete marker, which becomes the current version of the
object. If there isn't a null version, Amazon S3 does not remove any objects.

Use the response object to see if it succeeded or not.

For more information, please refer to
[Amazon's documentation for DELETE](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectDELETE.html).

## copy\_object( $src\_bucket, $src\_key, $dst\_bucket, $dst\_key )

**Arguments**: a list with source (bucket, key) and destination (bucket, key)

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

This method is a variation of the PUT operation as described by
Amazon's S3 API. It creates a copy of an object that is already stored
in Amazon S3. This "PUT copy" operation is the same as performing a GET
from the old bucket/key and then a PUT to the new bucket/key.

For more information, please refer to
[Amazon's documentation for COPY](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectCOPY.html).

## put\_object( $bucket, $key, $content \[, $headers\] )

**Arguments**:

a list of the following items, in order:

- 1. bucket - a string with the destination bucket
- 2. key - a string with the destination key
- 3. content - a string with the content to be uploaded
- 4. headers (**optional**) - hashref with extra headr information

**Returns**: an [HTTP::Response](https://metacpan.org/pod/HTTP::Response) object for the request.

The PUT operation adds an object to a bucket. Amazon S3 never adds partial
objects; if you receive a success response, Amazon S3 added the entire
object to the bucket.

For more information, please refer to
[Amazon's documentation for PUT](http://docs.aws.amazon.com/AmazonS3/latest/API/RESTObjectPUT.html).

# TODO

lots of APIs are not implemented yet.

# REPOSITORY

[https://github.com/DQNEO/Amazon-S3-Thin](https://github.com/DQNEO/Amazon-S3-Thin)

# LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

DQNEO

## ORIGINAL AUTHOR

Timothy Appnel <tima@cpan.org> [Amazon::S3](https://metacpan.org/pod/Amazon::S3)
[https://github.com/tima/perl-amazon-s3](https://github.com/tima/perl-amazon-s3)

# SEE ALSO

[Amazon::S3](https://metacpan.org/pod/Amazon::S3), [Net::Amazon::S3](https://metacpan.org/pod/Net::Amazon::S3)

[Amazon S3 API Reference : REST API](http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html)

[Amazon S3 API Reference : List of Error Codes](http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList)
