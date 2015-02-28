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

# DESCRIPTION

Amazon::S3::Thin - A thin, ligthweight, low-level Amazon S3 client.

- Low Level

    It returns HTTP::Response. So you can inspect easily what's happening inside , and can handle error as you like.

- Low Dependency

    It does not depend on any XML::\* modules, so that you can install it easily.

- Low Learning Cost

    The interfaces are designed to follow S3 official REST APIs. So it is easy to learn.

# TO DO

lots of APIs are not implemented yet.

# LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

DQNEO

# SEE ALSO

[Amazon::S3](https://metacpan.org/pod/Amazon::S3), [Net::Amazon::S3](https://metacpan.org/pod/Net::Amazon::S3)
