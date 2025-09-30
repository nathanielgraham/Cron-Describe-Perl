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
    plan tests => 6;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 L * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L in DayOfMonth') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '0 0 12 15W * ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid W in DayOfMonth') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * MON#2', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid # in DayOfWeek') or diag explain $errors;

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * * BAD#2', type => 'quartz') };
    like($@, qr/Invalid # syntax/, 'Invalid # syntax');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 32 * ?', type => 'quartz') };
    like($@, qr/Value 32 out of range/i, 'Invalid DayOfMonth');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz', timezone => 'Invalid/TZ') };
    like($@, qr/Invalid timezone/, 'Invalid timezone');
};

subtest 'Easy cases' => sub {
    plan tests => 2;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic daily Quartz') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '0 0,15 12 * * ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz list') or diag explain $errors;
};

subtest 'Medium cases' => sub {
    plan tests => 2;

    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * * ?', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz range') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '0 0 12 * JAN,FEB ?', type => 'quartz');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz month names') or diag explain $errors;
};

subtest 'Edge cases' => sub {
    plan tests => 3;

    my $cron;
    eval { $cron = Cron::Describe->new(cron_str => '0 0 0 ? 2 2#5', type => 'quartz') };
    like($@, qr/Fifth weekday in February/i, 'Impossible fifth Monday in Feb');

    $cron = Cron::Describe->new(cron_str => '0 0 12 29 * ? 2024', type => 'quartz');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29, 2024)') or diag explain $errors;

    eval { $cron = Cron::Describe->new(cron_str => '0 0 12 15 * MON', type => 'quartz') };
    like($@, qr/Either DayOfMonth or DayOfWeek must be \?/, 'DayOfMonth and DayOfWeek conflict');
};

done_testing;
