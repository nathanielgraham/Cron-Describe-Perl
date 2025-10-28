#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Cron::Toolkit;
use Time::Moment;

# Base time: October 27, 2025, 00:00:00 UTC (Monday)
my $base = Time::Moment->from_string('2025-10-27T00:00:00Z');
my $base_epoch = $base->epoch;

my @tests = (
    {
        expr => '* * * * *',
        desc => 'every minute',
        next_expected => $base_epoch + 60,   # 00:01:00
        prev_expected => $base_epoch - 60,   # 23:59:00 previous day
    },
    {
        expr => '0 0 * * *',
        desc => 'every hour at :00',
        next_expected => $base_epoch + 3600, # 01:00:00
        prev_expected => $base_epoch - 3600, # 23:00:00 previous day
    },
    {
        expr => '0 0 * * 1',
        desc => 'every hour on Sunday (Quartz normalized)',
        next_expected => $base_epoch + (6 * 86400) + 3600, # Nov 2 01:00 (adjust if needed)
        prev_expected => $base_epoch - 86400 - 3600,       # Oct 26 23:00
    },
    {
        expr => '0 0 0 1 * ? *',
        desc => 'first of every month at midnight',
        next_expected => $base->with_month(11)->with_day_of_month(1)->epoch,
        prev_expected => $base->with_month(10)->with_day_of_month(1)->epoch,
    },
    {
        expr => '0 0 0 L * ? *',
        desc => 'last day of month at midnight',
        next_expected => $base->with_day_of_month($base->length_of_month)->epoch,
        prev_expected => $base->minus_months(1)->with_day_of_month($base->minus_months(1)->length_of_month)->epoch,
    },
    {
        expr => '*/15 * * * *',
        desc => 'every 15 minutes',
        next_expected => $base_epoch + 900,  # 00:15:00
        prev_expected => $base_epoch - 900,  # 23:45:00 previous day
    },
    {
        expr => '0 9-17 * * *',
        desc => 'business hours (9-17) at top of hour',
        next_expected => $base_epoch + (9 * 3600),  # 09:00 same day
        prev_expected => $base_epoch - (7 * 3600),  # 17:00 previous day
    },
);

foreach my $t (@tests) {
    my $cron = Cron::Toolkit->new(expression => $t->{expr});

    # Test next()
    #my $next = $cron->next($base_epoch);
    my $next = $cron->next();
    print STDERR "NEXT: $next \n";
    is($next, $t->{next_expected}, "next() for $t->{desc} from base $base_epoch");

    # Test previous()
    my $prev = $cron->previous($base_epoch);
    is($prev, $t->{prev_expected}, "previous() for $t->{desc} from base $base_epoch");
}

done_testing;
