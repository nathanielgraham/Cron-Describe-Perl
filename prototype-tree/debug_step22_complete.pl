#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';
use Cron::Describe;
use Data::Dumper;

sub dump_tree {
    my ($node, $indent) = @_;
    $indent //= 0;
    my $prefix = '  ' x $indent;
    print $prefix, "Type: ", $node->{type}, ", Value: '", $node->{value} || '', "'\n";
    for my $child (@{$node->{children} || []}) {
        dump_tree($child, $indent + 1);
    }
}

my $expression = "0 10-20/5 8 * * ? *";
my $cron = Cron::Describe->new(expression => $expression);
my $root = $cron->{root};
print "=== ROOT TREE STRUCTURE FOR '$expression' ===\n";
dump_tree($root);
print "=== FIELD TYPES ===\n";
print Dumper($cron->{field_types});
print "=== CHILDREN COUNT ===\n";
print "Total children: ", scalar @{$root->{children}}, "\n";
