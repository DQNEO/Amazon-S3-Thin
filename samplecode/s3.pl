#!/usr/bin/env perl
# command tool like aws s3
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . '/../lib';
use Amazon::S3::Thin;
use S3;
use Config::Tiny;

use Data::Dumper;
my $profile = "dqneo";
my $config_file = $ENV{HOME} . "/.aws/credentials";

my $crd = Config::Tiny->read($config_file)->{$profile};

warn Dumper $crd;


package S3;

# inspired by https://github.com/Songmu/App-LJ
sub new_with_options {

}
