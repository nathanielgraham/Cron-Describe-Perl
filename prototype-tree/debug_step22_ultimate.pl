#!/usr/bin/perl
use strict;
use lib 'lib';
use Cron::Describe;
use Data::Dumper;

my $cron = Cron::Describe->new(expression => "0 10-20/5 8 * * ? *");
my @children = @{$cron->{root}->{children}};
my $minute_node = $children[1];

print "=== TREE PARSER CHECK ===\n";
print "Raw minute field: '10-20/5'\n";
print "=== MINUTE NODE STRUCTURE ===\n";
print Dumper($minute_node);
print "=== CHILDREN DETAILS ===\n";
my @min_children = $minute_node->get_children;
print "Child 0 Type: ", $min_children[0]->{type}, "\n";
print "Child 1 Type: ", $min_children[1]->{type}, "\n";
print "Child 1 Value: '", $min_children[1]->{value}, "'\n";  # KEY!
print "=== ENGLISH VISITOR CHECK ===\n";
print "Minute desc: '", $minute_node->to_english("minute"), "'\n";
print "Hour desc: '", $children[2]->to_english("hour"), "'\n";
print "=== SPECIAL CASE CHECK ===\n";
my $minute_desc = $minute_node->to_english("minute");
my $hour_desc = $children[2]->to_english("hour");
print "Regex match? ", $minute_desc =~ /every \d+ minutes/ ? "YES" : "NO", "\n";
print "Hour digit? ", $hour_desc =~ /^\d+$/ ? "YES" : "NO", "\n";
