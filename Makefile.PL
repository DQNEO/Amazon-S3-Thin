#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Amazon::S3::Simple',
    VERSION_FROM => 'lib/Amazon/S3/Simple.pm',
    AUTHOR       => 'DQNEO <dqneoo@gmail.com>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'Class::Accessor::Fast'      => '0',
        'Digest::HMAC_SHA1'          => '0',
        'HTTP::Date'                 => '0',
        'MIME::Base64'               => '0',
        'Test::More'                 => '0.01',    # for testing
        'URI::Escape'                => '0',
    }
);
