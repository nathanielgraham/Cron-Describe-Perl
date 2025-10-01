#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

# Ensure module loads
use_ok('Cron::Describe::Quartz');

# Test cases: [expression, is_valid, expected_desc, test_name]
my @tests = (
    ['0 0 0 * * ?', 1, 'at 0:0:0 on every day-of-month, every month, every day-of-week', 'Every day at midnight'],
    ['0 0 0 L * ?', 1, 'at 0:0:0 on last day, every month, every day-of-week', 'Last day of month'],
    ['0 0 0 15W * ?', 1, 'at 0:0:0 on nearest weekday to the 15, every month, every day-of-week', 'Nearest weekday to 15th'],
    ['0 0 0 * * 1#5', 1, 'at 0:0:0 on every day-of-month, every month, fifth Monday', '5th Monday'],
    ['0 0 0 * * 1#6', 0, undef, '6th Monday impossible'],
    ['0 60 0 * * ?', 0, undef, 'Invalid minute'],
    ['0 0 0 31 2 ?', 0, undef, '31st of February impossible'],
    ['0 0 0 * * 1L', 1, 'at 0:0:0 on every day-of-month, every month, last Monday', 'Last Monday of month'],
    ['0 0 0 * * ? 2025', 1, 'at 0:0:0 on every day-of-month, every month, every day-of-week, 2025', 'Every day in 2025'],
    ['0 0 0 1-5,10-15/2 * ?', 1, 'at 0:0:0 on 1-5, 10-15 every 2, every month, every day-of-week', 'Complex DOM pattern'],
);

for my $test (@tests) {
    my ($expr, $valid, $desc, $name) = @$test;
    my $cron = eval { Cron::Describe::Quartz->new(expression => $expr) };
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
