requires 'perl', '5.008001';
requires 'Digest::HMAC_SHA1';
requires 'HTTP::Date';
requires 'MIME::Base64';
requires 'LWP::UserAgent';
requires 'URI::Escape';
requires 'Class::Accessor::Fast';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

