#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Ensure module loads
use_ok('Cron::Describe::Standard');

# Test cases: [expression, is_valid, expected_desc, test_name]
my @tests = (
    ['* * * * *', 1, 'Runs at 00:00 on every day-of-month, every month, every day-of-week', 'Every minute'],
    ['0 0 1 * *', 1, 'Runs at 00:00 on 01, every month, every day-of-week', 'Midnight on 1st'],
    ['1-5,10-15/2 * * * *', 1, 'Runs at 01-05,10-15 every 2 on every day-of-month, every month, every day-of-week', 'Complex minute pattern'],
    ['60 * * * *', 0, undef, 'Invalid minute'],
    ['* * 31 2 *', 0, undef, '31st of February impossible'],
    ['0 0 * * SUN', 1, 'Runs at 00:00 on every day-of-month, every month, Sunday', 'Every Sunday midnight'],
    ['*/15 * * * *', 1, 'Runs at every 15 minutes starting at 00 on every day-of-month, every month, every day-of-week', 'Every 15 minutes'],
    ['1,3,5 * * JAN,FEB *', 1, 'Runs at 01,03,05 on every day-of-month, January, February, every day-of-week', 'Specific minutes in Jan/Feb'],
);

for my $test (@tests) {
    my ($expr, $valid, $desc, $name) = @$test;
    subtest $name => sub {
        my $cron = eval { Cron::Describe::Standard->new(expression => $expr) };
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
