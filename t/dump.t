#!/usr/bin/env perl
use strict;
use warnings;
use Cron::Toolkit;
use Data::Dumper;
use JSON::PP;

open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("JSON missing");
my $json = do { local $/; <$fh> };
my @tests = @{ JSON::PP->new->decode($json) };
for my $test (@tests) {
   eval {
      my $cron = Cron::Toolkit->new(expression => $test->{expr});
      print Dumper($cron->{fields});
      print Dumper($cron->{root});
      print $cron->as_string . "\n";
      print $cron->as_quartz_string . "\n";
      print $cron->dump_tree . "\n";
   };
   print "$@\n" if $@; 
}
