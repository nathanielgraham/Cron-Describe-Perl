# Tests for Quartz Scheduler cron expressions
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

subtest 'Constructor dispatch' => sub {
    plan tests => 3;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?');
    isa_ok($cron, 'Cron::Describe::Quartz', '6 fields -> Quartz');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz') };
    ok(!$@, 'Explicit quartz type');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * * *', type => 'quartz') };
    like($@, qr/Quartz cron requires 6-7 fields/, 'Too few fields for Quartz');
};

subtest 'Field parsing' => sub {
    plan tests => 10;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 L * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, last day of the month, any day of week', 'Description for L');

    $cron = Cron::Describe->new(cron_str => '0 0 12 15W * ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid W in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, nearest weekday to the 15th, any day of week', 'Description for W');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * MON#2', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid # in DayOfWeek') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, any day of month, the 2nd mon day', 'Description for #');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * * BAD#2', type => 'quartz') };
    like($@, qr/Invalid # syntax/, 'Invalid # syntax');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 32 * ?', type => 'quartz') };
    like($@, qr/Value 32 out of range/i, 'Invalid DayOfMonth');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz', timezone => 'Invalid/TZ') };
    like($@, qr/Invalid timezone/, 'Invalid timezone');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 32W * ?', type => 'quartz') };
    like($@, qr/W value 32 out of range/, 'Invalid W value');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 L-32 * ?', type => 'quartz') };
    like($@, qr/L offset 32 out of range/, 'Invalid L offset');
};

subtest 'Easy cases' => sub {
    plan tests => 4;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic daily Quartz') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, any day of month, any day of week', 'Description for daily');

    $cron = Cron::Describe->new(cron_str => '0 0,15 12 * * ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz list') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0,15 minutes, at 12 hours, any day of month, any day of week', 'Description for list');
};

subtest 'Medium cases' => sub {
    plan tests => 6;

    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz range') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, from 1 to 5 hours, any day of month, any day of week', 'Description for range');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * JAN,FEB ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz month names') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, any day of month, jan,feb months, any day of week', 'Description for month names');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * BAD ?', type => 'quartz') };
    like($@, qr/Invalid syntax in field: BAD/, 'Invalid month name');
};

subtest 'Edge cases' => sub {
    plan tests => 8;

    my $cron;
    eval { $cron = Cron::Describe->new(cron_str => '0 0 0 ? 2 2#5', type => 'quartz') };
    like($@, qr/Fifth weekday in February/, 'Impossible fifth Monday in Feb');

    $cron = Cron::Describe->new(cron_str => '0 0 12 29 * ? 2024', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29, 2024)') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, at 29 days-of-month, any day of week, at 2024 year', 'Description for leap year');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 15 * MON', type => 'quartz') };
    like($@, qr/Either DayOfMonth or DayOfWeek must be \?/, 'DayOfMonth and DayOfWeek conflict');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 30 4 ?', type => 'quartz') };
    like($@, qr/Day 30 invalid for 4/, 'Invalid day for April');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-3 * ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L-3 in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, 3 days before the last day of the month, any day of week', 'Description for L-3');
};

subtest 'Unusual patterns' => sub {
    plan tests => 14;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 1,3-5/2 * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Combined list and range with step') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, at 1, every 2 days from 3 to 5, any day of week', 'Description for list and range with step');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?/0', type => 'quartz') };
    like($@, qr/Step value cannot be zero/, 'Zero step');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 -1 * ?', type => 'quartz') };
    like($@, qr/Invalid syntax/i, 'Negative number');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 a * ?', type => 'quartz') };
    like($@, qr/Invalid syntax/i, 'Non-numeric');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 30 4 ?', type => 'quartz') };
    like($@, qr/Day 30 invalid for 4/, 'Invalid day for April');

    $cron = Cron::Describe->new(cron_str => '1-5/2,10 0 12 * * ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Range with step and list') or diag explain $errors;
    is($cron->describe, 'every 2 seconds from 1 to 5, at 10 seconds, at 0 minute, at 12 hours, any day of month, any day of week', 'Description for range with step and list');

    $cron = Cron::Describe->new(cron_str => '0 0 12 1,15 * SUN,MON', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Multiple days and months') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, at 1,15 days-of-month, sun,mon days', 'Description for multiple days');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * L 2023', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Last Saturday in year') or diag explain $errors;
    is($cron->describe, 'at 0 second, at 0 minute, at 12 hours, any day of month, last Saturday, at 2023 year', 'Description for L and year');

    $cron = Cron::Describe->new(cron_str => '0 1-5/2 12 1-3,15 JAN,FEB ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Complex combined pattern') or diag explain $errors;
    is($cron->describe, 'at 0 second, every 2 minutes from 1 to 5, at 12 hours, at 1,2,3,15 days-of-month, jan,feb months, any day of week', 'Description for complex pattern');
};

done_testing;
