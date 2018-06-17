use strict;
use Test::More 0.98;

use_ok $_ for qw(
    Amazon::S3::Thin
    Amazon::S3::Thin::Signer
    Amazon::S3::Thin::Signer::V2
    Amazon::S3::Thin::Signer::V4
);

done_testing;

