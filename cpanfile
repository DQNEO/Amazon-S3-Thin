requires 'perl', '5.010001';
requires 'Digest::HMAC_SHA1';
requires 'HTTP::Date';
requires 'MIME::Base64';
requires 'LWP::UserAgent';
requires 'URI::Escape';
requires 'Encode';
requires 'Digest::MD5';
requires 'AWS::Signature4';
requires 'Config::Tiny';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

on 'develop' => sub {
    requires 'LWP::Protocol::https';
    requires 'Config::Tiny';
}
