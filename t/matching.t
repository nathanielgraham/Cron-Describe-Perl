#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 0.88;
use Cron::Toolkit;
use Time::Moment;

eval { require JSON::MaybeXS };
plan skip_all => "JSON::MaybeXS required" if $@;

open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("JSON missing");
my $json = do { local $/; <$fh> };
my @tests = @{ JSON::MaybeXS->new->decode($json) };

my @valid_match = grep { !$_->{invalid} && defined $_->{match}{epoch} } @tests;
my @schedule_valid = grep { !$_->{invalid} && defined $_->{schedule}{next_epoch} } @tests;
plan tests => scalar(@valid_match) * 2 + scalar(@schedule_valid) * 4 + 6;  # is_match, next/prev/n + bounds

subtest 'is_match' => sub {
    plan tests => scalar(@valid_match);
    for my $test (@valid_match) {
        my $cron = Cron::Toolkit->new(expression => $test->{expr});
        if ($test->{tz}) { $cron->time_zone($test->{tz}); }
        my $epoch = $test->{match}{epoch};
        next unless defined $epoch;  # Skip nulls
        is($cron->is_match($epoch), $test->{match}{is_match}, "Matches epoch $epoch");
    }
};

subtest 'next / previous / next_n' => sub {
    plan tests => scalar(@schedule_valid) * 3;
    for my $test (@schedule_valid) {
        my $cron = Cron::Toolkit->new(expression => $test->{expr});
        if ($test->{tz}) { $cron->time_zone($test->{tz}); }

        # Next
        my $next = $cron->next;
        is($next, $test->{schedule}{next_epoch}, "Next: $test->{schedule}{next_epoch}");

        # Previous
        my $prev = $cron->previous;
        is($prev, $test->{schedule}{prev_epoch}, "Prev: $test->{schedule}{prev_epoch}");

        # next_n
        my $n3 = $cron->next_n(undef, 3);
        is_deeply($n3, $test->{schedule}{next_n}, "next_n[3]");
    }
};

subtest 'previous_n Alias next_occurrences' => sub {
    plan tests => 2;
    my $cron = Cron::Toolkit->new(expression => '0 30 14 * * ?');
    is_deeply($cron->previous_n(undef, 1), [$cron->previous], "previous_n(1)");
    is_deeply($cron->next_occurrences(undef, 1), [$cron->next], "next_occurrences alias");
};

subtest 'Bounds Clamping' => sub {
    plan tests => 4;
    my $bounded = Cron::Toolkit->new(expression => "0 0 * * * ?");
    $bounded->begin_epoch(Time::Moment->new(year => 2025, month => 10, day => 23)->epoch);
    $bounded->end_epoch(Time::Moment->new(year => 2025, month => 10, day => 24)->epoch);
    is($bounded->begin_epoch, 1761177600, "begin getter");
    is($bounded->end_epoch, 1761264000, "end getter");
    my $next_clamp = $bounded->next(1761091200);  # Past
    is($next_clamp, 1761177600, "Clamps to begin");
    my $after_end = $bounded->next(1761264001);  # After
    ok(!defined $after_end, "Undef after end");
};

done_testing;
