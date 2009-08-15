#!perl
use strict;
use warnings;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME         => 'Amazon::S3',
    VERSION_FROM => 'lib/Amazon/S3.pm',
    AUTHOR       => 'Timothy Appnel <tima@cpan.org>',
    LICENSE      => 'perl',
    PREREQ_PM    => {
        'Class::Accessor::Fast'      => '0',
        'Digest::MD5::File'          => '0',       # for testing
        'Digest::HMAC_SHA1'          => '0',
        'HTTP::Date'                 => '0',
        'IO::File'                   => '0',
        'LWP::UserAgent::Determined' => '0',
        'MIME::Base64'               => '0',
        'Test::More'                 => '0.01',    # for testing
        'XML::Simple'                => '1.08',
        'URI::Escape'                => '0',
    }
);
