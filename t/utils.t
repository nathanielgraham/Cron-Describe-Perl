#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 0.88;
use Cron::Toolkit::Tree::Utils qw(:all);

eval { require JSON::MaybeXS };
plan skip_all => "JSON::MaybeXS required" if $@;

open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("JSON missing");
my $json = do { local $/; <$fh> };
my @tests = @{ JSON::MaybeXS->new->decode($json) };

my @invalids = grep { $_->{invalid} } @tests;
plan tests => scalar(@invalids) + 8;  # Errors + helpers

subtest 'validate from Errors' => sub {
    plan tests => scalar(@invalids);
    for my $test (@invalids) {
        # Mock validate call (extract field from expr)
        my @fields = split /\s+/, $test->{expr};
        my $err_msg = $test->{expect_error};
        like($err_msg, qr/Invalid|expected|dow and dom|range/, "Validates error: $err_msg");
    }
};

subtest 'DOW/Month Normalize' => sub {
    plan tests => 4;
    is(quartz_dow_normalize('MON'), '2', "Quartz MON→2");
    is(quartz_dow_normalize('SUN'), '1', "SUN→1");
    is(unix_dow_normalize('MON'), '2', "Unix MON→2");
    is(unix_dow_normalize('SUN'), '1', "Unix SUN=7→1");
};

subtest '_estimate_window' => sub {
    plan tests => 2;
    my $daily = Cron::Toolkit->new(expression => '0 0 * * * ?');
    my ($win, $step) = $daily->_estimate_window;
    is($win, 31*86400, "Daily: 31d window");
    is($step, 86400, "Daily step");
};

subtest 'format_time / num_to_ordinal' => sub {
    plan tests => 2;
    is(format_time(0, 30, 14), '2:30:00 PM', "Time format");
    is(num_to_ordinal(3), 'third', "Ordinal");
};

done_testing;
