use strict;
use warnings;
use Amazon::S3::Thin::Signer::V4;
use Test::More;
use HTTP::Request;

{
  diag "test sign";

  my $request = HTTP::Request->new(GET => 'https://mybucket.s3.amazonaws.com/myfile.txt');
  $request->header('Date' => 'Wed, 28 Mar 2007 01:49:49 +0000');
  my $signer = Amazon::S3::Thin::Signer::V4->new({
      aws_access_key_id => 'accesskey',
      aws_secret_access_key => 'secretkey',
    });
  $signer->sign($request);
  $DB::single = 1;
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
  diag "test signer";

  my $signer = Amazon::S3::Thin::Signer::V4->new({
      aws_access_key_id => 'accesskey',
      aws_secret_access_key => 'secretkey',
    });
  my $signer_signer = $signer->signer;
  isa_ok($signer_signer, 'AWS::Signature4', 'signer');
  is_deeply($signer_signer, {
      access_key => 'accesskey',
      secret_key => 'secretkey',
    }, 'signer keys');
}

done_testing;
