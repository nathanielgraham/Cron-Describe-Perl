#!/usr/bin/perl
use strict;
use lib 'lib';
use Cron::Describe;
use Data::Dumper;

my $cron = Cron::Describe->new(expression => "0 10-20/5 8 * * ? *");
my @children = @{$cron->{root}->{children}};
my $minute_node = $children[1];
print "=== MINUTE NODE ===\n";
print Dumper($minute_node);
print "=== MINUTE CHILDREN ===\n";
my @min_children = $minute_node->get_children;
print "Child 0 (Base): ", Dumper($min_children[0]);
print "Child 1 (Step): ", Dumper($min_children[1]);
print "Step Value: ", $min_children[1]->{value}, "\n";
print "=== to_english OUTPUT ===\n";
print "Minute: '", $minute_node->to_english("minute"), "'\n";
print "Hour: '", $children[2]->to_english("hour"), "'\n";
