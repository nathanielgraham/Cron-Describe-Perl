use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

plan tests => 3;

# Easy cases
my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
my ($valid, $errors) = $cron->is_valid;
ok($valid, 'Basic hourly standard') or diag explain $errors;

$cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz');
($valid, $errors) = $cron->is_valid;
ok($valid, 'Basic daily Quartz') or diag explain $errors;

eval { Cron::Describe->new(cron_str => '60 0 * * *') };
like($@, qr/Invalid.*range/i, 'Invalid minute caught');

done_testing;
