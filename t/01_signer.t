use strict;
use warnings;
use Amazon::S3::Thin::Signer;
use Test::More;
use HTTP::Headers;

# What this test does is only to calculate signature,
# no HTTP communication.
{
    my $signer = Amazon::S3::Thin::Signer->new("secretfoobar");
    my $hdr = HTTP::Headers->new;

    $hdr->header("content-length", 15);
    $hdr->header("date", 'Sun, 01 Mar 2015 15:11:25 GMT');

    my $verb = "PUT";
    my $path = "example/file%2Etxt";
    my $sig = $signer->calculate_signature($verb,$path,$hdr);

    is $sig, "n4W+Lf9QQAbx5mo8N3sHWaJUQ/I=";
}

{
    my $secret_key = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';

    my $verb = "GET";
    my $date = "Tue, 27 Mar 2007 19:36:42 +0000";
    my $path = "johnsmith/photos/puppy.jpg";
    my $string_to_sign = $verb . "\n\n\n$date\n/$path";


    my $hmac = Digest::HMAC_SHA1->new($secret_key);
    $hmac->add($string_to_sign);
    my $signature = $hmac->b64digest . '=';

    ok $signature;
    is $signature, 'bWq2s1WEIj+Ydj0vQ697zp+IXMU=', "puppy test";
}

done_testing;
