#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Ensure module loads
use_ok('Cron::Describe::Quartz');

# Test cases: [expression, is_valid, expected_desc, test_name]
my @tests = (
    ['0 0 0 * * ?', 1, 'Runs at 00:00:00 on every day-of-month, every month, every day-of-week', 'Every day at midnight'],
    ['0 0 0 L * ?', 1, 'Runs at 00:00:00 on last day, every month, every day-of-week', 'Last day of month'],
    ['0 0 0 15W * ?', 1, 'Runs at 00:00:00 on nearest weekday to the 15, every month, every day-of-week', 'Nearest weekday to 15th'],
    ['0 0 0 * * 1#5', 1, 'Runs at 00:00:00 on every day-of-month, every month, fifth Monday', '5th Monday'],
    ['0 0 0 * * 1#6', 0, undef, '6th Monday impossible'],
    ['0 60 0 * * ?', 0, undef, 'Invalid minute'],
    ['0 0 0 31 2 ?', 0, undef, '31st of February impossible'],
    ['0 0 0 * * 1L', 1, 'Runs at 00:00:00 on every day-of-month, every month, last Monday', 'Last Monday of month'],
    ['0 0 0 * * ? 2025', 1, 'Runs at 00:00:00 on every day-of-month, every month, every day-of-week, 2025', 'Every day in 2025'],
    ['0 0 0 1-5,10-15/2 * ?', 1, 'Runs at 00:00:00 on 01-05,10-15 every 2, every month, every day-of-week', 'Complex DOM pattern'],
    ['0 0 0 LW * ?', 1, 'Runs at 00:00:00 on last weekday, every month, every day-of-week', 'Last weekday of month'],
    ['5/10 * * * * ?', 1, 'Runs at 00:05,15,25,35,45,55:00 on every day-of-month, every month, every day-of-week', 'Every 10 seconds starting at 5'],
    ['0 5/15 * * * ?', 1, 'Runs at 00:05,20,35,50:00 on every day-of-month, every month, every day-of-week', 'Every 15 minutes starting at 5'],
    ['0 0 0 * * 2#3', 1, 'Runs at 00:00:00 on every day-of-month, every month, third Tuesday', 'Third Tuesday'],
    ['0 0 0 LW * MON', 0, undef, 'LW with specific DOW invalid'],
);

for my $test (@tests) {
    my ($expr, $valid, $desc, $name) = @$test;
    subtest $name => sub {
        my $cron = eval { Cron::Describe::Quartz->new(expression => $expr) };
        if ($@) {
            ok(!$valid, "Failed to parse ($@)");
            return;
        }
        is($cron->is_valid(), $valid, "is_valid");
        if ($valid) {
            is($cron->describe(), $desc, "describe");
        }
    };
}

done_testing();
