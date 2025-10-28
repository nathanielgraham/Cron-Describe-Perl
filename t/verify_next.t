#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Cron::Toolkit;
use Time::Moment;

# Base time: Floor now_utc to minute for clean tests
my $base = Time::Moment->now_utc;
$base = $base->plus_seconds(-$base->second)->plus_minutes(-$base->minute);
my $base_epoch = $base->epoch;
diag "Base time: " . $base->strftime('%Y-%m-%d %H:%M:%S UTC') . " (epoch $base_epoch)";

my @tests = (
    {
        expr => '* * * * *',
        desc => 'every minute',
        next_tm => $base->plus_minutes(1),
        prev_tm => $base->minus_minutes(1),
    },
    {
        expr => '0 * * * * ?',
        desc => 'every hour at :00',
        next_tm => $base->plus_hours(1)->with_minute(0),
        prev_tm => $base->minus_hours(1)->with_minute(0),
    },
    {
        expr => '0 0 * * * ?',
        desc => 'daily at midnight',
        next_tm => $base->plus_days(1)->with_hour(0)->with_minute(0),
        prev_tm => $base->minus_days(1)->with_hour(0)->with_minute(0),
    },
    {
        expr => '0 0 * * 2',  # Tuesday (Unix DOW 2)
        desc => 'every Tuesday at midnight',
        next_tm => $base->plus_days(7)->with_hour(0)->with_minute(0),
        prev_tm => $base->minus_days(7)->with_hour(0)->with_minute(0),
    },
    {
        expr => '0 0 0 1 * ? *',
        desc => 'first of every month at midnight',
        next_tm => $base->plus_months(1)->with_day_of_month(1)->with_hour(0)->with_minute(0),
        prev_tm => $base->with_day_of_month(1)->with_hour(0)->with_minute(0),
    },
    {
        expr => '0 0 0 L * ? *',
        desc => 'last day of month at midnight (Quartz)',
        next_tm => $base->plus_months(1)->with_day_of_month($base->plus_months(1)->length_of_month)->with_hour(0)->with_minute(0),
        prev_tm => $base->with_day_of_month($base->length_of_month)->with_hour(0)->with_minute(0),
    },
    {
        expr => '*/15 * * * * ?',
        desc => 'every 15 minutes',
        next_tm => $base->plus_minutes(15 - ($base->minute % 15) || 15),
        prev_tm => $base->minus_minutes(($base->minute % 15) || 15),
    },
);

plan tests => scalar(@tests) * 2;

foreach my $t (@tests) {
    my $cron = Cron::Toolkit->new(expression => $t->{expr});
    diag "Testing: $t->{desc} ('$t->{expr}')";

    # next()
    my $next_epoch = $cron->next($base_epoch);
    my $next_expected = $t->{next_tm}->epoch;
    is($next_epoch, $next_expected, "next() for $t->{desc}")
        or diag "  Got: " . ($next_epoch ? Time::Moment->from_epoch($next_epoch)->strftime('%Y-%m-%d %H:%M:%S') : 'undef') . 
                "\n  Expected: " . $t->{next_tm}->strftime('%Y-%m-%d %H:%M:%S') . " (epoch $next_expected)";

    # previous()
    my $prev_epoch = $cron->previous($base_epoch);
    my $prev_expected = $t->{prev_tm}->epoch;
    is($prev_epoch, $prev_expected, "previous() for $t->{desc}")
        or diag "  Got: " . ($prev_epoch ? Time::Moment->from_epoch($prev_epoch)->strftime('%Y-%m-%d %H:%M:%S') : 'undef') . 
                "\n  Expected: " . $t->{prev_tm}->strftime('%Y-%m-%d %H:%M:%S') . " (epoch $prev_expected)";
}

done_testing;
