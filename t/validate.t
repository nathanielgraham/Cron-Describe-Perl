#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Ensure module loads
use_ok('Cron::Describe::Standard');

# Test cases: [expression, is_valid, expected_desc, test_name]
my @tests = (
    ['* * * * *', 1, 'at 0:0:0 on every day-of-month, every month, every day-of-week', 'Every minute'],
    ['0 0 1 * *', 1, 'at 0:0:0 on 1, every month, every day-of-week', 'Midnight on 1st'],
    ['1-5,10-15/2 * * * *', 1, 'at 0:1-5, 10-15 every 2:0 on every day-of-month, every month, every day-of-week', 'Complex minute pattern'],
    ['60 * * * *', 0, undef, 'Invalid minute'],
    ['* * 31 2 *', 0, undef, '31st of February impossible'],
    ['0 0 * * SUN', 1, 'at 0:0:0 on every day-of-month, every month, 0', 'Every Sunday midnight'],
    ['*/15 * * * *', 1, 'at 0:every 15 minutes:0 on every day-of-month, every month, every day-of-week', 'Every 15 minutes'],
    ['1,3,5 * * JAN,FEB *', 1, 'at 0:1, 3, 5:0 on every day-of-month, 1, 2, every day-of-week', 'Specific minutes in Jan/Feb'],
);

for my $test (@tests) {
    my ($expr, $valid, $desc, $name) = @$test;
    my $cron = eval { Cron::Describe::Standard->new(expression => $expr) };
    if ($@) {
        ok(!$valid, "$name: Failed to parse ($@)");
        next;
    }
    is($cron->is_valid(), $valid, "$name: is_valid");
    if ($valid) {
        is($cron->describe(), $desc, "$name: describe");
    }
}

done_testing();
