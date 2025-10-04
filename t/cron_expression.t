use strict;
use warnings;
use Test::More;
use Time::Moment;

BEGIN {
    use_ok('Cron::Describe::CronExpression');
    use_ok('Cron::Describe::Pattern');
    use_ok('Cron::Describe::WildcardPattern');
    use_ok('Cron::Describe::UnspecifiedPattern');
    use_ok('Cron::Describe::SinglePattern');
    use_ok('Cron::Describe::RangePattern');
    use_ok('Cron::Describe::StepPattern');
    use_ok('Cron::Describe::ListPattern');
    use_ok('Cron::Describe::DayOfMonthPattern');
    use_ok('Cron::Describe::DayOfWeekPattern');
}

subtest 'Expression: 0 0 0 * * ?' => sub {
    my $expr;
    eval {
        $expr = Cron::Describe::CronExpression->new('0 0 0 * * ?');
    };
    ok(!$@, 'Created CronExpression object without error') or diag "Error: $@";
    return unless $expr;
    is($expr->{type}, 'quartz', 'Detected correct type: quartz');
    ok($expr->validate, 'Expression validates');
    my $tm = Time::Moment->new(
        year       => 2025,
        month      => 10,
        day        => 3,
        hour       => 0,
        minute     => 0,
        second     => 0,
    );
    ok($expr->is_match($tm), 'Matches midnight on any day');
};

subtest 'Invalid Expression: ? in wrong field' => sub {
    eval { Cron::Describe::CronExpression->new('? 0 0 * * *') };
    like($@, qr/Unspecified pattern '\?' is only valid for day_of_month or day_of_week/, 'Rejects ? in seconds field');
};

done_testing;
