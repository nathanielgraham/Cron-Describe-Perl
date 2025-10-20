#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Time::Moment;
use Cron::Describe;

sub utc_epoch {
    my (%components) = @_;
    return Time::Moment->new(%components)->epoch;
}

plan tests => 20;

# 1-2. UTC Basic
my $cron_utc = Cron::Describe->new(expression => "0 0 12 * * ?");
is $cron_utc->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 12, minute => 0, second => 0)), 1, "1. UTC 12:00";
is $cron_utc->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 12, minute => 1, second => 0)), 0, "2. UTC 12:01";

# 3-4. NY Timezone
my $cron_ny = Cron::Describe->new(expression => "0 0 12 * * ?", utc_offset => -300);
is $cron_ny->utc_offset, -300, "3. NY offset";
is $cron_ny->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 17, minute => 0, second => 0)), 1, "4. NY 12:00";

# 5-7. Steps
my $step_cron = Cron::Describe->new(expression => "*/15 * * * * ?");
is $step_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 12, minute => 0, second => 0)), 1, "5. step 0";
is $step_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 12, minute => 15, second => 0)), 1, "6. step 15";
is $step_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 12, minute => 0, second => 7)), 0, "7. step 7";

# 8-9. Ranges
my $range_cron = Cron::Describe->new(expression => "0 0 10-14 * * ?");
is $range_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 12, minute => 0, second => 0)), 1, "8. range 12";
is $range_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 9, minute => 0, second => 0)), 0, "9. range 9";

# 10-12. Lists
my $list_cron = Cron::Describe->new(expression => "0 0 0 1,15 * * ?");
is $list_cron->is_match(utc_epoch(year => 2023, month => 10, day => 1, hour => 0, minute => 0, second => 0)), 1, "10. list 1";
is $list_cron->is_match(utc_epoch(year => 2023, month => 10, day => 15, hour => 0, minute => 0, second => 0)), 1, "11. list 15";
is $list_cron->is_match(utc_epoch(year => 2023, month => 10, day => 10, hour => 0, minute => 0, second => 0)), 0, "12. list 10";
# 13. DOW Monday
my $dow_cron = Cron::Describe->new(expression => "0 0 0 * * 2 ?");
is $dow_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 0, minute => 0, second => 0)), 1, "13. Monday";

# 14. DOW ?
my $dow_q_cron = Cron::Describe->new(expression => "0 0 0 * * ? *");
is $dow_q_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 0, minute => 0, second => 0)), 1, "14. DOW ?";

# 15-16. Last Day
my $last_cron = Cron::Describe->new(expression => "0 0 0 L * ? *");
is $last_cron->is_match(utc_epoch(year => 2023, month => 10, day => 31, hour => 0, minute => 0, second => 0)), 1, "15. Oct 31 last";
is $last_cron->is_match(utc_epoch(year => 2023, month => 10, day => 30, hour => 0, minute => 0, second => 0)), 0, "16. Oct 30 not last";

# 17. L-2
my $l2_cron = Cron::Describe->new(expression => "0 0 0 L-2 * ? *");
is $l2_cron->is_match(utc_epoch(year => 2023, month => 10, day => 29, hour => 0, minute => 0, second => 0)), 1, "17. L-2 Oct 29";

# 18. LW
my $lw_cron = Cron::Describe->new(expression => "0 0 0 LW * ? *");
is $lw_cron->is_match(utc_epoch(year => 2023, month => 10, day => 31, hour => 0, minute => 0, second => 0)), 1, "18. LW Oct 31";

# 19. Nth DOW
my $nth_cron = Cron::Describe->new(expression => "0 0 0 * * 1#2 ?");
is $nth_cron->is_match(utc_epoch(year => 2023, month => 10, day => 8, hour => 0, minute => 0, second => 0)), 1, "19. 2nd Sunday";

# 20. Nearest Weekday
my $nw_cron = Cron::Describe->new(expression => "0 0 0 16W * ? *");
is $nw_cron->is_match(utc_epoch(year => 2023, month => 10, day => 16, hour => 0, minute => 0, second => 0)), 1, "20. 16W Oct 16";

done_testing;
