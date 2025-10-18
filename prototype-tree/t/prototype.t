use strict;
use warnings;
use Test::More;
use Cron::Describe;
use Time::Moment;

my $cron = Cron::Describe->new(expression => "0 0 1-5/2 * *");
ok($cron, "Tree built");

my $tm = Time::Moment->new(year=>2025, month=>10, day=>1, hour=>0, minute=>0);
is($cron->is_match($tm), 1, "Match test for day 1");

is($cron->to_english, "every 2 dom from 1st through 5th", "English test");

done_testing;
