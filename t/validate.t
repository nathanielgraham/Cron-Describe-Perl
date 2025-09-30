# Tests for standard UNIX cron expressions
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

subtest 'Constructor dispatch' => sub {
    plan tests => 3;

    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    isa_ok($cron, 'Cron::Describe::Standard', '5 fields -> Standard');
    
    eval { Cron::Describe->new(cron_str => '0 0 * * *', type => 'standard') };
    ok(!$@, 'Explicit standard type');
    
    eval { Cron::Describe->new(cron_str => '0 0 * * * ?', type => 'quartz') };
    like($@, qr/Invalid standard cron.*Quartz-specific/, 'Quartz chars in standard type');
};

subtest 'Field parsing' => sub {
    plan tests => 7;

    my $cron = Cron::Describe->new(cron_str => '0 0,15 1-5 1,6 MON');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid fields: list, range, day name') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0,15 hours, from 1 to 5 days-of-month, at 1,6 months, mon day', 'Description for list, range, names');

    $cron = Cron::Describe->new(cron_str => '*/15 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid step: */15') or diag explain $errors;
    is($cron->describe, 'every 15 minutes, at 0 hour', 'Description for step');

    eval { $cron = Cron::Describe->new(cron_str => '60 0 * * *') };
    like($@, qr/Value 60 out of range/i, 'Invalid minute');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * * BAD') };
    like($@, qr/Invalid syntax/i, 'Invalid day name');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * 13 *') };
    like($@, qr/Value 13 out of range/i, 'Invalid month');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * BAD *') };
    like($@, qr/Invalid syntax/i, 'Invalid month name');
};

subtest 'Easy cases' => sub {
    plan tests => 4;

    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic hourly standard') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0 hour', 'Description for hourly');

    $cron = Cron::Describe->new(cron_str => '0 0,15 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard list') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0,15 hours', 'Description for list');
};

subtest 'Medium cases' => sub {
    plan tests => 6;

    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard range') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0 hour, from 1 to 5 days-of-month', 'Description for range');

    $cron = Cron::Describe->new(cron_str => '0 0 * JAN,FEB MON-WED');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Month and day names') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0 hour, jan,feb months, mon-wed days', 'Description for names');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 31 4 *') };
    like($@, qr/Day 31 invalid for 4/, 'Invalid day for April');
};

subtest 'Edge cases' => sub {
    plan tests => 6;

    my $cron;
    eval { $cron = Cron::Describe->new(cron_str => '0 0 * 15 * MON') };
    like($@, qr/both be specified/i, 'DayOfMonth and DayOfWeek conflict');

    $cron = Cron::Describe->new(cron_str => '0 0 29 2 *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29)') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0 hour, at 29 days-of-month, feb month', 'Description for leap year');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * * *#2') };
    like($@, qr/Invalid standard cron.*Quartz-specific/, 'Quartz # in standard');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 30 4 *') };
    like($@, qr/Day 30 invalid for 4/, 'Invalid day for April');
};

subtest 'Unusual patterns' => sub {
    plan tests => 10;

    my $cron = Cron::Describe->new(cron_str => '1,3-5/2 * * * *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Combined list and range with step') or diag explain $errors;
    is($cron->describe, 'at 1, from 3 to 5 every 2 minutes', 'Description for list and range with step');

    eval { $cron = Cron::Describe->new(cron_str => '*/0 * * * *') };
    like($@, qr/Step value cannot be zero/, 'Zero step');

    eval { $cron = Cron::Describe->new(cron_str => '-1 * * * *') };
    like($@, qr/Invalid syntax/i, 'Negative number');

    eval { $cron = Cron::Describe->new(cron_str => 'a * * * *') };
    like($@, qr/Invalid syntax/i, 'Non-numeric');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 30 4 *') };
    like($@, qr/Day 30 invalid for 4/, 'Invalid day for April');

    $cron = Cron::Describe->new(cron_str => '1-5/2,10 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Range with step and list') or diag explain $errors;
    is($cron->describe, 'from 1 to 5 every 2 minutes, at 10 minutes', 'Description for range with step and list');

    $cron = Cron::Describe->new(cron_str => '0 0 1,15 * SUN,MON');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Multiple days and months') or diag explain $errors;
    is($cron->describe, 'at 0 minute, at 0 hour, at 1,15 days-of-month, sun,mon days', 'Description for multiple days');
};

done_testing;
