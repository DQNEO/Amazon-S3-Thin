#!/usr/bin/env perl
# command tool like aws s3
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin . '/../lib';
use Amazon::S3::Thin;
#use S3::CLI;
use Config::Tiny;

S3::CLI->new->run(@ARGV);


package S3::CLI;
use strict;
use warnings;

use Data::Dumper;

sub new {
    return {}, shift;
}

sub run {

    my $profile = "dqneo";
my $config_file = $ENV{HOME} . "/.aws/credentials";

my $crd = Config::Tiny->read($config_file)->{$profile};

warn Dumper $crd;


}
