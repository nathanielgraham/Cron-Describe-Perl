#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 0.88;
use Cron::Toolkit;
eval { require JSON::MaybeXS };
plan skip_all => "JSON::MaybeXS required" if $@;
open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("JSON missing");
my $json = do { local $/; <$fh> };
my @tests = @{ JSON::MaybeXS->new->decode($json) };
my @valid_desc = grep { !$_->{invalid} && $_->{desc} } @tests;
subtest 'describe()' => sub {
    for my $test (@valid_desc) {
        my $cron = Cron::Toolkit->new(expression => $test->{expr});
        if ($test->{tz}) { $cron->time_zone($test->{tz}); }
        is($cron->describe, $test->{desc}, "Desc: $test->{desc}");
    }
};
subtest 'Fusions (e.g., month+year+nth)' => sub {
    # From JSON '0 0 0 * * 1#2 ?' – second Sunday
    my $nth = Cron::Toolkit->new(expression => '0 0 0 * * 1#2 ?');
    like($nth->describe, qr/second Sunday/, "Nth fusion");
    # Year constrain '0 0 0 * * ? 2025'
    my $year = Cron::Toolkit->new(expression => '0 0 0 * * ? 2025');
    like($year->describe, qr/in 2025/, "Year fusion");
};
done_testing;
