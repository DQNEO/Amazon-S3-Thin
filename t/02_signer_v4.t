use strict;
use warnings;
use Amazon::S3::Thin::Signer::V4;
use Amazon::S3::Thin::Credentials;
use Test::More;
use HTTP::Request;

my $credentials = Amazon::S3::Thin::Credentials->new('accesskey', 'secretkey');

{
  diag "test signer";

  my $signer = Amazon::S3::Thin::Signer::V4->new($credentials);
  my $signer_signer = $signer->signer;
  isa_ok($signer_signer, 'AWS::Signature4', 'signer');
  is_deeply($signer_signer, {
      access_key => 'accesskey',
      secret_key => 'secretkey',
    }, 'signer keys');
}

{
  diag "test sign";

  my $request = HTTP::Request->new(GET => 'https://mybucket.s3.amazonaws.com/myfile.txt');
  $request->header('Date' => 'Wed, 28 Mar 2007 01:49:49 +0000');
  my $signer = Amazon::S3::Thin::Signer::V4->new($credentials);
  $signer->sign($request);
  my $headers = [ sort split /\n/, $request->headers->as_string ];
  is_deeply ($headers, [
      'Authorization: AWS4-HMAC-SHA256 Credential=accesskey/20070328/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=0dea3c9b65eede067ce9e38d48558a63924a6a08a8d21c27cfd7de50e5c78d4b',
      'Date: Wed, 28 Mar 2007 01:49:49 +0000',
      'Host: mybucket.s3.amazonaws.com',
      'X-Amz-Content-SHA256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      'X-Amz-Date: 20070328T014949Z',
    ], 'Request headers');
}

{
    diag "test sign (session token)";

    my $request = HTTP::Request->new(GET => 'https://mybucket.s3.amazonaws.com/myfile.txt');
    $request->header('Date' => 'Wed, 28 Mar 2007 01:49:49 +0000');
    my $credentials = Amazon::S3::Thin::Credentials->new('accesskey', 'secretkey', 'sessiontoken');
    my $signer = Amazon::S3::Thin::Signer::V4->new($credentials);
    $signer->sign($request);
    my $headers = [ sort split /\n/, $request->headers->as_string ];
    is_deeply ($headers, [
        'Authorization: AWS4-HMAC-SHA256 Credential=accesskey/20070328/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token, Signature=54a046a4241ef546a30aec8d9e9a1e91c2d095be24baaef1797350cd2cfef2fd',
        'Date: Wed, 28 Mar 2007 01:49:49 +0000',
        'Host: mybucket.s3.amazonaws.com',
        'X-Amz-Content-SHA256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'X-Amz-Date: 20070328T014949Z',
        'X-Amz-Security-Token: sessiontoken',
    ], 'Request headers');
}

done_testing;
