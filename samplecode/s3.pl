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

    my $p = Getopt::Long::Parser->new(
        config => [qw(posix_default no_ignore_case bundling)],
        );

    $p->getoptionsfromarray(
        \@args,
        "p|profile=s"   => \(my $profile),
        "h|help"        => \(my $help),
        "v|version"     => \(my $version),
    );
    if ($version) {
        printf "s3%s\n", Daiku->VERSION;
        exit 0;
    }
    if ($help) {
        require Pod::Usage;
        Pod::Usage::pod2usage(0);
    }

    my $subcmd = shift @args;

    #warn Dumper $subcmd, $profile , \@args;    n
    if ($subcmd eq "ls") {
        return $self->cmd_ls(@args);
    }
    #my $config_file = $ENV{HOME} . "/.aws/credentials";
    #my $crd = Config::Tiny->read($config_file)->{$profile};
    #warn Dumper $crd;

}

sub cmd_ls {
    my ($self, $url) = @_;
    print "url:$url\n";
}
