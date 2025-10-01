# Tests for standard UNIX cron expressions
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

subtest 'Constructor dispatch' => sub {
    plan tests => 4;

    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    isa_ok($cron, 'Cron::Describe::Standard', '5 fields -> Standard');
    
    eval { Cron::Describe->new(cron_str => '0 0 * * *', type => 'standard') };
    ok(!$@, 'Explicit standard type');
    
    my $cron2 = Cron::Describe->new(cron_str => '0 0 * * * ?');
    my ($valid, $errors) = $cron2->is_valid;
    ok(!$valid, 'Quartz chars in standard type');
    like($errors->{syntax}, qr/Invalid standard cron.*Quartz-specific/, 'Quartz chars in standard type error');
};

subtest 'Field parsing' => sub {
    plan tests => 8;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0,15 * * 1');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid fields: list, numeric day') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0,15 hours, mon day', 'Description for list, numeric day');

    $cron = Cron::Describe->new(cron_str => '*/15 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid step: */15') or diag explain $errors;
    is($cron->describe, 'every 15 minutes, at 0 hours', 'Description for step');

    $cron = Cron::Describe->new(cron_str => '60 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid minute');
    like($errors->{range}, qr/Value 60 out of range/i, 'Invalid minute error');

    $cron = Cron::Describe->new(cron_str => '0 0 * 13 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid month');
    like($errors->{range}, qr/Value 13 out of range/i, 'Invalid month error');

    $cron = Cron::Describe->new(cron_str => '0 0 * BAD *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid month name');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Invalid month name error');
};

subtest 'Easy cases' => sub {
    plan tests => 4;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic hourly standard') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours', 'Description for hourly');

    $cron = Cron::Describe->new(cron_str => '0 0,15 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard list') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0,15 hours', 'Description for list');
};

subtest 'Medium cases' => sub {
    plan tests => 6;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard range') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours, from 1 to 5 days', 'Description for range');

    $cron = Cron::Describe->new(cron_str => '0 0 * JAN,FEB MON-WED');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Month and day names') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours, jan,feb months, mon-wed days', 'Description for names');

    $cron = Cron::Describe->new(cron_str => '0 0 31 4 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 31 invalid for 4/, 'Invalid day for April error');
};

subtest 'Edge cases' => sub {
    plan tests => 8;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 * 15 * MON');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'DayOfMonth and DayOfWeek conflict');
    like($errors->{conflict}, qr/both be specified/i, 'DayOfMonth and DayOfWeek conflict error');

    $cron = Cron::Describe->new(cron_str => '0 0 29 2 *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29)') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours, at 29 days, feb month', 'Description for leap year');

    $cron = Cron::Describe->new(cron_str => '0 0 * * *#2');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Quartz # in standard');
    like($errors->{syntax}, qr/Invalid standard cron.*Quartz-specific/, 'Quartz # in standard error');

    $cron = Cron::Describe->new(cron_str => '0 0 30 4 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 30 invalid for 4/, 'Invalid day for April error');
};

subtest 'Unusual patterns' => sub {
    plan tests => 12;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '1,3-5/2 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Combined list and range with step') or diag explain $errors;
    is($cron->describe, 'at 1, every 2 minutes from 3 to 5', 'Description for list and range with step');

    $cron = Cron::Describe->new(cron_str => '*/0 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Zero step');
    like($errors->{step}, qr/Step value cannot be zero/, 'Zero step error');

    $cron = Cron::Describe->new(cron_str => '-1 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Negative number');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Negative number error');

    $cron = Cron::Describe->new(cron_str => 'a * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Non-numeric');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Non-numeric error');

    $cron = Cron::Describe->new(cron_str => '1-5/2,10 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Range with step and list') or diag explain $errors;
    is($cron->describe, 'every 2 minutes from 1 to 5, at 10 minutes', 'Description for range with step and list');

    $cron = Cron::Describe->new(cron_str => '0 0 1,15,30 4 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day list for April');
    like($errors->{range}, qr/Days 30 invalid for 4/, 'Invalid day list for April error');
};

done_testing;
