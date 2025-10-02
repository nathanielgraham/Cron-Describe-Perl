use strict;
use warnings;
use Test::More;
use Time::Moment;
use DateTime::TimeZone;
use Cron::Describe::Standard;
use Cron::Describe::Quartz;

# Plan for 66 tests (20 Standard + 21 Quartz + 14 is_match + 6 next/previous)
plan tests => 66;

# Helper to create epoch timestamps
sub make_epoch {
    my ($year, $month, $day, $hour, $minute, $second, $tz) = @_;
    my $tm = Time::Moment->new(
        year => $year,
        month => $month,
        day => $day,
        hour => $hour,
        minute => $minute,
        second => $second,
    );
    # Base.pm handles timezone, so return epoch directly
    return $tm->epoch;
}

# Standard Cron Parsing and Validation (20 tests)
subtest 'Standard Cron Parsing and Validation' => sub {
    plan tests => 20;
    my $cron = Cron::Describe::Standard->new(expression => '* * * * *', timezone => 'UTC');
    ok($cron->is_valid, 'Wildcard expression is valid');
    is($cron->to_english, 'Runs at 00:00 on every day-of-month, every month, every day-of-week', 'Wildcard description');
    $cron = Cron::Describe::Standard->new(expression => '0 0 1 * *', timezone => 'UTC');
    ok($cron->is_valid, 'Specific day expression is valid');
    is($cron->to_english, 'Runs at 00:00 on day-of-month 1, every month, every day-of-week', 'Specific day description');
    $cron = Cron::Describe::Standard->new(expression => '60 * * * *', timezone => 'UTC');
    ok(!$cron->is_valid, 'Invalid minute is caught');
    like($cron->{errors}->[0] // '', qr/Invalid minute|Out of bounds/, 'Invalid minute error');
    $cron = Cron::Describe::Standard->new(expression => '0,15,30 9-17 * * 1-5', timezone => 'UTC');
    ok($cron->is_valid, 'Ranges and lists are valid');
    is($cron->to_english, 'Runs at 00,15,30 minutes past every hour from 09 through 17 on every day-of-month, every month, every Monday through Friday', 'Ranges and lists description');
    $cron = Cron::Describe::Standard->new(expression => '*/5 * * * *', timezone => 'UTC');
    ok($cron->is_valid, 'Step expression is valid');
    is($cron->to_english, 'Runs at every 5th minute past every hour on every day-of-month, every month, every day-of-week', 'Step description');
    $cron = Cron::Describe::Standard->new(expression => '0 12 * * 0', timezone => 'UTC');
    ok($cron->is_valid, 'Sunday at noon is valid');
    is($cron->to_english, 'Runs at 12:00 on every day-of-month, every month, every Sunday', 'Sunday description');
    $cron = Cron::Describe::Standard->new(expression => '0 0 31 2 *', timezone => 'UTC');
    ok(!$cron->is_valid, 'Invalid Feb 31 is caught');
    like($cron->{errors}->[0] // '', qr/day-of-month/, 'Feb 31 error');
    $cron = Cron::Describe::Standard->new(expression => '0 0 * * 1,3,5', timezone => 'UTC');
    ok($cron->is_valid, 'Multiple days of week valid');
    is($cron->to_english, 'Runs at 00:00 on every day-of-month, every month, every Monday,Wednesday,Friday', 'Multiple DOW description');
    $cron = Cron::Describe::Standard->new(expression => 'ABC * * * *', timezone => 'UTC');
    ok(!$cron->is_valid, 'Non-numeric minute caught');
    like($cron->{errors}->[0] // '', qr/Invalid format/, 'Non-numeric minute error');
    $cron = Cron::Describe::Standard->new(expression => '0 25 * * *', timezone => 'UTC');
    ok(!$cron->is_valid, 'Invalid hour caught');
    like($cron->{errors}->[0] // '', qr/Invalid hour|Out of bounds/, 'Invalid hour error');
};

# Quartz Cron Parsing and Validation (21 tests)
subtest 'Quartz Cron Parsing and Validation' => sub {
    plan tests => 21;
    my $cron = Cron::Describe::Quartz->new(expression => '0 * * * * ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz wildcard with ? is valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on every day-of-month, every month, every day-of-week', 'Quartz wildcard description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 L * ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz L is valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on last day-of-month, every month, every day-of-week', 'Quartz L description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 15W * ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz W is valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on nearest weekday to day-of-month 15, every month, every day-of-week', 'Quartz W description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 * * 2#3 ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz # is valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on every day-of-month, every month, every 3rd Tuesday', 'Quartz # description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 1 1 ? 2025', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz year is valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on day-of-month 1, January, every day-of-week, 2025', 'Quartz year description');
    $cron = Cron::Describe::Quartz->new(expression => '0/10 * * * * ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz step seconds valid');
    is($cron->to_english, 'Runs at every 10th second on every minute, every hour, every day-of-month, every month, every day-of-week', 'Quartz step seconds description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 ? * ? *', timezone => 'UTC');
    ok(!$cron->is_valid, 'Quartz ?/? invalid');
    like($cron->{errors}->[0] // '', qr/cannot be '\?'/, 'Quartz ?/? error');
    $cron = Cron::Describe::Quartz->new(expression => '60 * * * * ?', timezone => 'UTC');
    ok(!$cron->is_valid, 'Quartz invalid second caught');
    like($cron->{errors}->[0] // '', qr/Invalid second|Out of bounds/, 'Quartz invalid second error');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 1-5 * ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz DOM range valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on days-of-month 1 through 5, every month, every day-of-week', 'Quartz DOM range description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 * * 1-3 ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz DOW range valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on every day-of-month, every month, every Monday through Wednesday', 'Quartz DOW range description');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 * * ABC ?', timezone => 'UTC');
    ok(!$cron->is_valid, 'Quartz invalid DOW caught');
    like($cron->{errors}->[0] // '', qr/Invalid day-of-week|Invalid format/, 'Quartz invalid DOW error');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 * * LW ?', timezone => 'UTC');
    ok($cron->is_valid, 'Quartz LW is valid');
    is($cron->to_english, 'Runs at 0 seconds:00:00 on last weekday of every month, every day-of-week', 'Quartz LW description');
};

# Standard Cron is_match Tests (6 tests)
subtest 'Standard Cron is_match' => sub {
    plan tests => 6;
    my $cron = Cron::Describe::Standard->new(expression => '* * * * *', timezone => 'UTC');
    my $epoch = make_epoch(2025, 1, 1, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Wildcard matches any time');
    $cron = Cron::Describe::Standard->new(expression => '0 0 1 * *', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 1, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches Jan 1, 2025, 00:00:00');
    $epoch = make_epoch(2025, 1, 1, 1, 0, 0, 'UTC');
    ok(!$cron->is_match($epoch), 'Does not match Jan 1, 2025, 01:00:00');
    $cron = Cron::Describe::Standard->new(expression => '0,15,30 9-17 * * 1-5', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 6, 9, 15, 0, 'UTC'); # Monday
    ok($cron->is_match($epoch), 'Matches Monday 9:15');
    $epoch = make_epoch(2025, 1, 4, 9, 15, 0, 'UTC'); # Saturday
    ok(!$cron->is_match($epoch), 'Does not match Saturday');
    $cron = Cron::Describe::Standard->new(expression => '*/5 * * * *', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 1, 0, 10, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches every 5 minutes');
};

# Quartz Cron is_match Tests (5 tests)
subtest 'Quartz Cron is_match' => sub {
    plan tests => 5;
    my $cron = Cron::Describe::Quartz->new(expression => '0/5 * * * * ?', timezone => 'UTC');
    my $epoch = make_epoch(2025, 1, 1, 0, 0, 5, 'UTC');
    ok($cron->is_match($epoch), 'Matches every 5 seconds');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 1 1 ? 2025', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 1, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches Jan 1, 2025');
    $epoch = make_epoch(2026, 1, 1, 0, 0, 0, 'UTC');
    ok(!$cron->is_match($epoch), 'Does not match Jan 1, 2026');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 L * ?', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 31, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches last day of January');
    $epoch = make_epoch(2025, 2, 28, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches last day of February');
};

# Advanced Quartz is_match Tests (3 tests)
subtest 'Advanced Quartz is_match' => sub {
    plan tests => 3;
    my $cron = Cron::Describe::Quartz->new(expression => '0 0 0 15W * ?', timezone => 'UTC');
    my $epoch = make_epoch(2025, 1, 15, 0, 0, 0, 'UTC'); # Wednesday
    ok($cron->is_match($epoch), 'Matches Jan 15, 2025 (weekday)');
    $epoch = make_epoch(2025, 6, 16, 0, 0, 0, 'UTC'); # Jun 15 is Sunday, so 16 is Monday
    ok($cron->is_match($epoch), 'Matches nearest weekday for Jun 15');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 * * 2#3 ?', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 21, 0, 0, 0, 'UTC'); # 3rd Tuesday
    ok($cron->is_match($epoch), 'Matches 3rd Tuesday of January');
};

# Edge Case Tests for is_match (5 tests)
subtest 'Edge Cases for is_match' => sub {
    plan tests => 5;
    my $cron = Cron::Describe::Quartz->new(expression => '0 30 2 * * ?', timezone => 'UTC');
    my $epoch = make_epoch(2025, 3, 9, 2, 30, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches 2:30 on March 9, 2025');
    $cron = Cron::Describe::Quartz->new(expression => '0 30 1 * * ?', timezone => 'UTC');
    $epoch = make_epoch(2025, 11, 2, 1, 30, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches 1:30 on Nov 2, 2025');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 29 2 ?', timezone => 'UTC');
    $epoch = make_epoch(2028, 2, 29, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches Feb 29, 2028');
    $epoch = make_epoch(2027, 2, 28, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches Feb 28, 2027');
    $cron = Cron::Describe::Standard->new(expression => '0 0 0 1 1 1', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 1, 0, 0, 0, 'UTC'); # Sunday
    ok($cron->is_match($epoch), 'Matches Jan 1, 2025 (Sunday)');
};

# Next/Previous Tests (6 tests)
subtest 'Next and Previous Fire Times' => sub {
    plan tests => 6;
    my $cron = Cron::Describe::Standard->new(expression => '0 0 * * *', timezone => 'UTC');
    my $epoch = make_epoch(2025, 1, 1, 0, 30, 0, 'UTC'); # Jan 1, 2025, 00:30
    my $next = $cron->next($epoch);
    is($next, make_epoch(2025, 1, 1, 1, 0, 0, 'UTC'), 'Standard: Next hour at 00:00');
    my $prev = $cron->previous($epoch);
    is($prev, make_epoch(2025, 1, 1, 0, 0, 0, 'UTC'), 'Standard: Previous hour at 00:00');

    $cron = Cron::Describe::Quartz->new(expression => '0/5 * * * * ?', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 1, 0, 0, 2, 'UTC');
    $next = $cron->next($epoch);
    is($next, make_epoch(2025, 1, 1, 0, 0, 5, 'UTC'), 'Quartz: Next every 5 seconds');
    $prev = $cron->previous($epoch);
    is($prev, make_epoch(2025, 1, 1, 0, 0, 0, 'UTC'), 'Quartz: Previous every 5 seconds');

    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 15W * ?', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 14, 0, 0, 0, 'UTC');
    $next = $cron->next($epoch);
    is($next, make_epoch(2025, 1, 15, 0, 0, 0, 'UTC'), 'Quartz: Next nearest weekday to Jan 15');
    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 * * 2#3 ?', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 20, 0, 0, 0, 'UTC');
    $next = $cron->next($epoch);
    is($next, make_epoch(2025, 2, 18, 0, 0, 0, 'UTC'), 'Quartz: Next 3rd Tuesday (Feb)');
};

done_testing();
