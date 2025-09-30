use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

plan tests => 3;

# Medium difficulty
my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * * ?', type => 'quartz');
my ($valid, $errors) = $cron->is_valid;
ok($valid, 'Quartz range') or diag explain $errors;

$cron = Cron::Describe->new(cron_str => '0 0,15 * * *');
($valid, $errors) = $cron->is_valid;
ok($valid, 'Standard list') or diag explain $errors;

eval { Cron::Describe->new(cron_str => '0 0 * * MON,TUE#2') };
like($@, qr/Invalid.*Quartz-specific/i, 'Quartz # in standard cron');

done_testing;
