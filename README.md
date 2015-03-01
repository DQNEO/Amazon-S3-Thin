[![Build Status](https://travis-ci.org/DQNEO/Amazon-S3-Thin.svg?branch=master)](https://travis-ci.org/DQNEO/Amazon-S3-Thin)
# NAME

Amazon::S3::Thin - A thin, ligthweight, low-level Amazon S3 client

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

You can also pass any useragent as you like

    my $s3client = Amazon::S3::Thin->new(
        {   aws_access_key_id     => $aws_access_key_id,
            aws_secret_access_key => $aws_secret_access_key,
            ua                    => $any_LWP_copmatible_useragent,
        }
    );

# DESCRIPTION

Amazon::S3::Thin - A thin, ligthweight, low-level Amazon S3 client.

- Low Level

    It returns HTTP::Response. So you can inspect easily what's happening inside , and can handle error as you like.

- Low Dependency

    It does require no XML::\* modules, so that installation be easy;

- Low Learning Cost

    The interfaces are designed to follow S3 official REST APIs. So it is easy to learn.

# comparison to precedent modules

There are already usuful modules [Amazon::S3](https://metacpan.org/pod/Amazon::S3) and [Net::Amazon::S3](https://metacpan.org/pod/Net::Amazon::S3).
The 2 precedent modules provides "a Perlish interface", which is easy to understand for Perl programmers.
But they also hide low-level behaviors.
For example, the "get\_key" method returns undef on 404 status and raises exception on 5xx status.

In some situations, it is very important to see raw HTTP communications.
That's why I made this module.

# TO DO

lots of APIs are not implemented yet.

# REPOSITORY

https://github.com/DQNEO/Amazon-S3-Thin

# LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

DQNEO

## ORIGINAL AUTHOR

Timothy Appnel <tima@cpan.org> [Amazon::S3](https://metacpan.org/pod/Amazon::S3)
https://github.com/tima/perl-amazon-s3

# SEE ALSO

[Amazon::S3](https://metacpan.org/pod/Amazon::S3), [Net::Amazon::S3](https://metacpan.org/pod/Net::Amazon::S3)

Amazon S3 API Reference : REST API
http://docs.aws.amazon.com/AmazonS3/latest/API/APIRest.html

Amazon S3 API Reference : List of Error Codes
http://docs.aws.amazon.com/AmazonS3/latest/API/ErrorResponses.html#ErrorCodeList
