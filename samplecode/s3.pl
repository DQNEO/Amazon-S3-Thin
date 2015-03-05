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
use Getopt::Long;

use Data::Dumper;


sub new {
    return {}, shift;
}

sub run {
    my ($self, @args) = @_;
    my %opts = (
        );

    our $VERSION = "0.00";

    GetOptions(\%opts,
               'version',
               'debug',
        ) or $opts{help}++;

    warn Dumper \%opts;

    if ($opts{help}) {
        print "help\n";
        return 0;
    }

    if ($opts{version}) {
        print $VERSION , "\n";
        return 0;
    }

    my $profile = "dqneo";
    my $config_file = $ENV{HOME} . "/.aws/credentials";

    my $crd = Config::Tiny->read($config_file)->{$profile};

    warn Dumper $crd;

}
