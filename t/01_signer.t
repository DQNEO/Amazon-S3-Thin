use strict;
use warnings;
use Amazon::S3::Thin::SignerV2;
use Test::More;
use HTTP::Headers;

# What this test does is only to calculate signature,
# no HTTP communication.
{
    diag "test PUT request";
    my $secret_key = "secretfoobar";
    my $verb = "PUT";
    my $path = "example/file%2Etxt";

    my $hdr = HTTP::Headers->new;
    $hdr->header("content-length", 15);
    $hdr->header("date", 'Sun, 01 Mar 2015 15:11:25 GMT');

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $sig = $signer->calculate_signature($verb,$path,$hdr);

    is $sig, "n4W+Lf9QQAbx5mo8N3sHWaJUQ/I=";
}

{
    diag "test GET request with single subresource";
    my $secret_key = "somesecret";
    my $verb = "GET";
    my $path = "example/?delete";
    my $date = 'Sun, 01 Mar 2015 15:11:25 GMT';
    my $string_to_sign = "$verb\n\n\n$date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("date", $date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'IM6VtFJwF3z+lulFGux8tlU4N8Q=', "get with subresource";
}

{
    diag "test GET request with single subresource";
    my $secret_key = "somesecret";
    my $verb = "GET";
    my $path = 'example/?delete&versionId=4&invalid&acl&location="foo"';
    my $date = 'Sun, 01 Mar 2015 15:11:25 GMT';
    my $string_to_sign = "$verb\n\n\n$date\n/example/?acl&delete&location&versionId";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("date", $date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'OztMp7iNgvQVKXZQhXeIBz9UHnU=', "get with many subresources";
}


# test cases as described in
# http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html#RESTAuthenticationRequestCanonicalization
my $secret_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
{
    diag "test Amazon example object GET";

    my $verb = "GET";
    my $date = "Tue, 27 Mar 2007 19:36:42 +0000";
    my $path = "johnsmith/photos/puppy.jpg";
    my $string_to_sign = "$verb\n\n\n$date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'bWq2s1WEIj+Ydj0vQ697zp+IXMU=', "puppy test (GET)";
}

{
    diag "test Amazon example object PUT";

    my $verb           = "PUT";
    my $date           = "Tue, 27 Mar 2007 21:15:45 +0000";
    my $path           = "johnsmith/photos/puppy.jpg";
    my $content_type   = "image/jpeg";
    my $content_length = 94328;
    my $string_to_sign = "$verb\n\n$content_type\n$date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);
    $hdr->header("Content-Type", $content_type);
    $hdr->header("Content-Length", $content_length);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'MyyxeRY7whkBe+bq8fHCL/2kKUg=', "puppy test (PUT)";
}

{
    diag "test Amazon example list";

    my $verb           = "GET";
    my $date           = "Tue, 27 Mar 2007 19:42:41 +0000";
    my $path           = "johnsmith/?prefix=photos&max-keys=50&marker=puppy";
    my $user_agent     = "Mozilla/5.0";
    my $string_to_sign = "$verb\n\n\n$date\n/johnsmith/";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);
    $hdr->header("User-Agent", $user_agent);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'htDYFYduRNen8P9ZfE/s9SuKy0U=', "puppy list (GET)";
}

{
    diag "test Amazon example fetch";

    my $verb           = "GET";
    my $date           = "Tue, 27 Mar 2007 19:44:46 +0000";
    my $path           = "johnsmith/?acl";
    my $string_to_sign = "$verb\n\n\n$date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'c2WLPFtWHVgbEmeEG93a4cG37dM=', "puppy fetch (GET)";
}

{
    diag "test Amazon example delete";

    my $verb           = "DELETE";
    my $date           = "Tue, 27 Mar 2007 21:20:27 +0000";
    my $path           = "johnsmith/photos/puppy.jpg";
    my $user_agent     = "dotnet";
    my $amz_date       = "Tue, 27 Mar 2007 21:20:26 +0000";
    my $string_to_sign = "$verb\n\n\n$amz_date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);
    $hdr->header("User-Agent", $user_agent);
    $hdr->header("x-amz-date", $amz_date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'lx3byBScXR6KzyMaifNkardMwNk=', "puppy delete (DELETE)";
}

{
    diag "test Amazon example upload";

    my $verb           = "PUT";
    my $date           = "Tue, 27 Mar 2007 21:06:08 +0000";
# TODO: ports should be stripped from the path for signing
#    my $path           = "static.johnsmith.net:8080/db-backup.dat.gz";
    my $path           = "static.johnsmith.net/db-backup.dat.gz";
    my $user_agent     = "curl/7.15.5";
    my $x_amz_acl      = "public-read";
    my $content_type   = "application/x-download";
    my $content_md5    = "4gJE4saaMU4BqNR0kLY+lw==";
    my @x_amz_meta_reviewed_by = ('joe@johnsmith.net', 'jane@johnsmith.net');
    my $x_amz_meta_filechecksum = '0x02661779';
    my $x_amz_meta_checksum_algorithm = 'crc32';
    my $content_disposition = "attachment; filename=database.dat";
    my $content_encoding = "gzip";
    my $content_length   = 5913339;

    my $string_to_sign = "PUT\n4gJE4saaMU4BqNR0kLY+lw==\napplication/x-download\nTue, 27 Mar 2007 21:06:08 +0000\nx-amz-acl:public-read\nx-amz-meta-checksumalgorithm:crc32\nx-amz-meta-filechecksum:0x02661779\nx-amz-meta-reviewedby:joe\@johnsmith.net,jane\@johnsmith.net\n/static.johnsmith.net/db-backup.dat.gz";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);
    $hdr->header("User-Agent", $user_agent);
    $hdr->header("x-amz-acl", $x_amz_acl);
    $hdr->header("content-type", $content_type);
    $hdr->header("Content-MD5", $content_md5);
    $hdr->header("X-Amz-Meta-ReviewedBy", join(',' => @x_amz_meta_reviewed_by));
    $hdr->header("X-Amz-Meta-FileChecksum", $x_amz_meta_filechecksum);
    $hdr->header("X-Amz-Meta-ChecksumAlgorithm", $x_amz_meta_checksum_algorithm);
    $hdr->header("Content-Disposition", $content_disposition);
    $hdr->header("Content-Encoding", $content_encoding);
    $hdr->header("Content-Length", $content_length);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'ilyl83RwaSoYIEdixDQcA4OnAnc=', "puppy upload (PUT)";
}

{
    diag "test Amazon example list buckets";

    my $verb           = "GET";
    my $date           = "Wed, 28 Mar 2007 01:29:59 +0000";
    my $path           = "";
    my $string_to_sign = "$verb\n\n\n$date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'qGdzdERIC03wnaRNKh6OqZehG9s=', "puppy list buckets (GET)";
}

{
    diag "test Amazon example unicode keys";

    my $verb           = "GET";
    my $date           = "Wed, 28 Mar 2007 01:49:49 +0000";
    my $path           = "dictionary/fran%C3%A7ais/pr%c3%a9f%c3%a8re";
    my $string_to_sign = "$verb\n\n\n$date\n/$path";

    my $signer = Amazon::S3::Thin::SignerV2->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("Date", $date);

    is(
        $signer->string_to_sign($verb,$path,$hdr),
        $string_to_sign,
        'string to sign'
    );
    my $sig = $signer->calculate_signature($verb, $path, $hdr);
    is $sig, 'DNEZGsoieTZ92F3bUfSPQcbGmlM=', "puppy unicode keys";
}


done_testing;
