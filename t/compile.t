use strict;
use warnings;
use Test::More;

# Test compilation of all Cron::Describe modules
my @modules = qw(
    Cron::Describe
    Cron::Describe::Pattern
    Cron::Describe::WildcardPattern
    Cron::Describe::UnspecifiedPattern
    Cron::Describe::SinglePattern
    Cron::Describe::RangePattern
    Cron::Describe::StepPattern
    Cron::Describe::ListPattern
    Cron::Describe::DayOfMonthPattern
    Cron::Describe::DayOfWeekPattern
    Cron::Describe::Utils
);

foreach my $module (@modules) {
    use_ok($module);
}

done_testing;
