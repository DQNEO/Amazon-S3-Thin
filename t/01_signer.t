use strict;
use warnings;
use Amazon::S3::Thin::Signer;
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

    my $signer = Amazon::S3::Thin::Signer->new($secret_key);
    my $sig = $signer->calculate_signature($verb,$path,$hdr);

    is $sig, "n4W+Lf9QQAbx5mo8N3sHWaJUQ/I=";
}

{
    diag "test GET request";

    # test the case http://docs.aws.amazon.com/AmazonS3/latest/dev/RESTAuthentication.html#RESTAuthenticationRequestCanonicalization
    my $secret_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';

    my $verb = "GET";
    my $date = "Tue, 27 Mar 2007 19:36:42 +0000";
    my $path = "johnsmith/photos/puppy.jpg";
    my $string_to_sign = $verb . "\n\n\n$date\n/$path";

    my $signer = Amazon::S3::Thin::Signer->new($secret_key);
    my $hdr = HTTP::Headers->new;
    $hdr->header("date", $date);
    my $sig = $signer->calculate_signature($verb, $path, $hdr);

    is $sig, 'bWq2s1WEIj+Ydj0vQ697zp+IXMU=', "puppy test";
}

done_testing;
