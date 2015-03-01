#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Amazon::S3::Thin',
    VERSION_FROM => 'lib/Amazon/S3/Thin.pm',
    AUTHOR       => 'DQNEO <dqneoo@gmail.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'Digest::HMAC_SHA1'          => '0',
        'HTTP::Date'                 => '0',
        'MIME::Base64'               => '0',
        'Test::More'                 => '0.01',    # for testing
        'URI::Escape'                => '0',
    }
);
