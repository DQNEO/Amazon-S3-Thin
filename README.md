# NAME

Amazon::S3::Thin - A very simple, ligthweight Amazon S3 client

# SYNOPSIS

    use Amazon::S3::Thin;

    my $s3client = Amazon::S3::Thin->new(
        {   aws_access_key_id     => $aws_access_key_id,
            aws_secret_access_key => $aws_secret_access_key,
        }
    );

    $response = $s3client->get_object($bucket, $key);

    $response = $s3client->put_object($bucket, $key, "hello world");

    $response = $s3client->delete_object($bucket, $key);

    $response = $s3client->copy_object($src_bucket, $src_key,
                                       $dst_bucket, $dst_key);

    $response = $s3client->list_objects(
                                $bucket,
                                {prefix => "foo", delimter => "/"}
                               );

# LICENSE

Copyright (C) DQNEO.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

DQNEO
