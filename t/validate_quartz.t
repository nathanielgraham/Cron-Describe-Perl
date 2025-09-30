# Tests for Quartz Scheduler cron expressions
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

subtest 'Constructor dispatch' => sub {
    plan tests => 4;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?');
    isa_ok($cron, 'Cron::Describe::Quartz', '6 fields -> Quartz');

    eval { Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz') };
    ok(!$@, 'Explicit quartz type');

    my $cron2 = Cron::Describe->new(cron_str => '0 0 * * *');
    my ($valid, $errors) = $cron2->is_valid;
    ok(!$valid, 'Too few fields for Quartz');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Too few fields for Quartz error');
};

subtest 'Field parsing' => sub {
    plan tests => 12;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 12 L * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, last day of the month, every day-of-week', 'Description for L');

    $cron = Cron::Describe->new(cron_str => '0 0 12 15W * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid W in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, nearest weekday to the 15th, every day-of-week', 'Description for W');

    $cron = Cron::Describe->new(cron_str => '0 0 12 ? * MON#2');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid # in DayOfWeek') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, the 2nd mon day', 'Description for #');

    $cron = Cron::Describe->new(cron_str => '0 0 12 ? * BAD#2');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid # syntax');
    like($errors->{syntax}, qr/Invalid # syntax/, 'Invalid # syntax error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 32 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid DayOfMonth');
    like($errors->{range}, qr/Value 32 out of range/i, 'Invalid DayOfMonth error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz', timezone => 'Invalid/TZ');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid timezone');
    like($errors->{timezone}, qr/Invalid timezone/, 'Invalid timezone error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 32W * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid W value');
    like($errors->{range}, qr/W value 32 out of range/, 'Invalid W value error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-32 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid L offset');
    like($errors->{range}, qr/L offset 32 out of range/, 'Invalid L offset error');
};

subtest 'Easy cases' => sub {
    plan tests => 4;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic daily Quartz') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, every day-of-week', 'Description for daily');

    $cron = Cron::Describe->new(cron_str => '0 0,15 12 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz list') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0,15 minutes, at 12 hours, every day-of-month, every day-of-week', 'Description for list');
};

subtest 'Medium cases' => sub {
    plan tests => 6;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz range') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, from 1 to 5 hours, every day-of-month, every day-of-week', 'Description for range');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * JAN,FEB ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz month names') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, jan,feb months, every day-of-week', 'Description for month names');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * BAD ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid month name');
    like($errors->{syntax}, qr/Invalid syntax in field: BAD/, 'Invalid month name error');
};

subtest 'Edge cases' => sub {
    plan tests => 10;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 0 ? 2 2#5');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Impossible fifth Monday in Feb');
    like($errors->{impossible}, qr/Fifth weekday in February/, 'Impossible fifth Monday in Feb error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 29 * ? 2024');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29, 2024)') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, at 29 days, every day-of-week, at 2024 years', 'Description for leap year');

    $cron = Cron::Describe->new(cron_str => '0 0 12 15 * MON');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'DayOfMonth and DayOfWeek conflict');
    like($errors->{conflict}, qr/Either DayOfMonth or DayOfWeek must be \?/, 'DayOfMonth and DayOfWeek conflict error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 30 4 ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 30 invalid for 4/, 'Invalid day for April error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-3 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L-3 in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, 3 days before the last day of the month, every day-of-week', 'Description for L-3');
};

subtest 'Unusual patterns' => sub {
    plan tests => 18;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 12 1,3-5/2 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Combined list and range with step') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, at 1, every 2 days from 3 to 5, every day-of-week', 'Description for list and range with step');

    $cron = Cron::Describe->new(cron_str => '*/0 * * * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Zero step');
    like($errors->{step}, qr/Step value cannot be zero/, 'Zero step error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 -1 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Negative number');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Negative number error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 a * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Non-numeric');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Non-numeric error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 30 4 ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 30 invalid for 4/, 'Invalid day for April error');

    $cron = Cron::Describe->new(cron_str => '1-5/2,10 0 12 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Range with step and list') or diag explain $errors;
    is($cron->describe, 'every 2 seconds from 1 to 5, at 10 seconds, at 0 minutes, at 12 hours, every day-of-month, every day-of-week', 'Description for range with step and list');

    $cron = Cron::Describe->new(cron_str => '0 0 12 ? * 1,2');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Multiple days of week') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, mon,tue days', 'Description for multiple days');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * L 2023');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Last Saturday in year') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, last Saturday, at 2023 years', 'Description for L and year');

    $cron = Cron::Describe->new(cron_str => '0 1-5/2 12 1-3,15 JAN,FEB ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Complex combined pattern') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, every 2 minutes from 1 to 5, at 12 hours, at 1,2,3,15 days, jan,feb months, every day-of-week', 'Description for complex pattern');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-0 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L-0 in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, last day of the month, every day-of-week', 'Description for L-0');
};

done_testing;
