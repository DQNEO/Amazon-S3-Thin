use strict;
use warnings;
use Amazon::S3::Thin::Signer;
use Test::More;
use HTTP::Headers;

# What this test does is only to calculate signature,
# no HTTP communication. :)
{
    my $signer = Amazon::S3::Thin::Signer->new("secretfoobar");
    my $hdr = HTTP::Headers->new;

    $hdr->header("content-length", 15);
    $hdr->header("date", 'Sun, 01 Mar 2015 15:11:25 GMT');

    my $verb = "PUT";
    my $sig = $signer->calculate_signature($verb,"example/file%2Etxt",$hdr);

    is $sig, "n4W+Lf9QQAbx5mo8N3sHWaJUQ/I=";
}

is $sig, "n4W+Lf9QQAbx5mo8N3sHWaJUQ/I=";

done_testing;
