use strict;
use warnings;
use Amazon::S3::Thin::Signer;
use Test::More;

{
  diag "test new";

  my $obj = Amazon::S3::Thin::Signer->new({ signature_version => 4 });
  is_deeply($obj, { signature_version => 4 }, 'constructor args');
}

{
  diag "test factory";

  my $signer = Amazon::S3::Thin::Signer->factory({ signature_version => 4 });
  isa_ok($signer, 'Amazon::S3::Thin::Signer::V4', 'signer');
  is_deeply($signer, { signature_version => 4 }, 'signer args');
}

done_testing;
