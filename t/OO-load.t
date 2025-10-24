#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 0.88;

use_ok('Cron::Toolkit') or BAIL_OUT("Can't load Cron::Toolkit");

# Load Utils with real use for %aliases
use Cron::Toolkit::Tree::Utils qw(:all %aliases);

# Smoke new() with JSON data
eval { require JSON::MaybeXS };
if ($@) {
    plan skip_all => "JSON::MaybeXS required for data-driven tests";
}
open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("Missing t/data/cron_tests.json");
my $json = do { local $/; <$fh> };
my $tests = JSON::MaybeXS->new->decode($json);

my @valid = grep { !$_->{invalid} } @$tests;
my $sample = $valid[0];  # First valid
my $cron = Cron::Toolkit->new(expression => $sample->{expr});
ok($cron, "new() succeeds for sample: $sample->{expr}");
is($Cron::Toolkit::VERSION, '0.05', "Version");
is_deeply([sort keys %aliases], [sort qw(@annually @daily @hourly @midnight @monthly @weekly @yearly)], "Exports aliases");

done_testing;
