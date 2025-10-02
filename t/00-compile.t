use strict;
use warnings;
use Test::More;

my @modules = qw(
    Cron::Describe
    Cron::Describe::Base
    Cron::Describe::Field
    Cron::Describe::DayOfMonth
    Cron::Describe::DayOfWeek
    Cron::Describe::Standard
    Cron::Describe::Quartz
);

foreach my $module (@modules) {
    use_ok($module) or diag "Failed to load $module";
}

done_testing();
