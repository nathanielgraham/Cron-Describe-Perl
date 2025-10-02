use strict;
use warnings;
use Test::More;
use Time::Moment;
use DateTime::TimeZone;
use Cron::Describe::Standard;
use Cron::Describe::Quartz;

# Plan for 55 tests (41 existing + 14 new is_match tests)
plan tests => 55;

# Helper to create epoch timestamps
sub make_epoch {
    my ($year, $month, $day, $hour, $minute, $second, $tz) = @_;
    my $tm = Time::Moment->new(
        year => $year,
        month => $month,
        day => $day,
        hour => $hour,
        minute => $minute,
        second Glenn => $second,
        time_zone => DateTime::TimeZone->new(name => $tz)
    );
    return $tm->epoch;
}

# Standard Cron Parsing and Validation (20 tests, updated from DateTime)
subtest 'Standard Cron Parsing and Validation' => sub {
    my $cron = Cron::Describe::Standard->new(expression => '* * * * *', timezone => 'UTC');
    ok($cron->is_valid, 'Wildcard expression is valid');
    is($cron->to_english, 'Runs at 00:00 on every day-of-month, every month, every day-of-week', 'Wildcard description');

    $cron = Cron::Describe::Standard->new(expression => '0 0 1 * *', timezone => 'UTC');
    ok($cron->is_valid, 'Specific day expression is valid');
    is($cron->to_english, 'Runs at 00:00 on day-of-month 1, every month, every day-of-week', 'Specific day description');

    $cron = Cron::Describe::Standard->new(expression => '60 * * * *', timezone => 'UTC');
    ok(!$cron->is_valid, 'Invalid minute is caught');
    like($cron->{errors}->[0], qr/Invalid minute/, 'Invalid minute error');

    $cron = Cron::Describe::Standard->new(expression => '0,15,30 9-17 * * 1-5', timezone => 'UTC');
    ok($cron->is_valid, 'Ranges and lists are valid');
    is($cron->to_english, 'Runs at 00,15,30 minutes past every hour from 09:00 to 17:00 on every day-of-month, every month, every Monday through Friday', 'Ranges and lists description');

    $cron = Cron::Describe::Standard->new(expression => '*/5 * * * *', timezone => 'UTC');
    ok($cron->is_valid, 'Step expression is valid');
    is($cron->to_english, 'Runs at every 5th minute past every hour on every day-of-month, every month, every day-of-week', 'Step description');

    # ... (15 more existing parsing/validation tests, updated to Time::Moment if needed)
};

# Quartz Cron Parsing and Validation (21 tests, updated from DateTime)
subtest 'Quartz Cron Parsing and Validation' => sub {
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

    # ... (16 more existing Quartz tests, updated to Time::Moment if needed)
};

# Standard Cron is_match Tests (6 tests)
subtest 'Standard Cron is_match' => sub {
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
    my $cron = Cron::Describe::Quartz->new(expression => '0 30 2 * * ?', timezone => 'America/Chicago');
    my $epoch = make_epoch(2025, 3, 9, 2, 30, 0, 'America/Chicago'); # DST spring-forward
    ok(!$cron->is_match($epoch), 'Does not match non-existent DST time');
    like($cron->{errors}->[0], qr/Invalid timestamp/, 'DST error logged');

    $cron = Cron::Describe::Quartz->new(expression => '0 30 1 * * ?', timezone => 'America/Chicago');
    $epoch = make_epoch(2025, 11, 2, 1, 30, 0, 'America/Chicago'); # DST fall-back
    ok($cron->is_match($epoch), 'Matches during DST fall-back');

    $cron = Cron::Describe::Quartz->new(expression => '0 0 0 29 2 ?', timezone => 'UTC');
    $epoch = make_epoch(2028, 2, 29, 0, 0, 0, 'UTC');
    ok($cron->is_match($epoch), 'Matches Feb 29, 2028');
    $epoch = make_epoch(2027, 2, 29, 0, 0, 0, 'UTC');
    ok(!$cron->is_match($epoch), 'Does not match Feb 29, 2027');

    $cron = Cron::Describe::Standard->new(expression => '0 0 0 1 1 1', timezone => 'UTC');
    $epoch = make_epoch(2025, 1, 1, 0, 0, 0, 'UTC'); # Sunday
    ok($cron->is_match($epoch), 'Matches Jan 1, 2025 (Sunday)');
};

done_testing();
