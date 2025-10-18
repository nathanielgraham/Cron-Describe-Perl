#!/usr/bin/perl
use strict;
use lib 'lib';
use Cron::Describe;
use Data::Dumper;

my $cron = Cron::Describe->new(expression => "0 10-20/5 8 * * ? *");
my @children = @{$cron->{root}->{children}};
print "=== MINUTE FIELD (1) ===\n";
print Dumper($children[1]);
print "Type: ", $children[1]->{type}, "\n";
print "Children: ", scalar @{$children[1]->{children}}, "\n";
print "=== HOUR FIELD (2) ===\n";
print Dumper($children[2]);
print "Type: ", $children[2]->{type}, "\n";
print "Value: ", $children[2]->{value}, "\n";
