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
    plan tests => 5;

    my $cron = Cron::Describe->new(cron_str => '0 0,15 1-5 1,6 MON');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid fields: list, range, day name') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '*/15 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid step: */15') or diag explain $errors;

    eval { $cron = Cron::Describe->new(cron_str => '60 0 * * *') };
    like($@, qr/Value 60 out of range/i, 'Invalid minute');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * * BAD') };
    like($@, qr/Invalid day name/i, 'Invalid day name');

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * 13 *') };
    like($@, qr/Value 13 out of range/i, 'Invalid month');
};

subtest 'Easy cases' => sub {
    plan tests => 2;

    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic hourly standard') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '0 0,15 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard list') or diag explain $errors;
};

subtest 'Medium cases' => sub {
    plan tests => 2;

    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard range') or diag explain $errors;

    $cron = Cron::Describe->new(cron_str => '0 0 * JAN,FEB MON-WED');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Month and day names') or diag explain $errors;
};

subtest 'Edge cases' => sub {
    plan tests => 3;

    my $cron;
    eval { $cron = Cron::Describe->new(cron_str => '0 0 * 15 * MON') };
    like($@, qr/both be specified/i, 'DayOfMonth and DayOfWeek conflict');

    $cron = Cron::Describe->new(cron_str => '0 0 29 2 *');
    my ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29)') or diag explain $errors;

    eval { $cron = Cron::Describe->new(cron_str => '0 0 * * *#2') };
    like($@, qr/Invalid standard cron.*Quartz-specific/, 'Quartz # in standard');
};

done_testing;
