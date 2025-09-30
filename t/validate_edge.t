use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

plan tests => 3;

# Edge cases
eval { Cron::Describe->new(cron_str => '0 0 0 ? 2 2#5', type => 'quartz') };
like($@, qr/Invalid.*February/i, 'Impossible fifth Monday in Feb');

$cron = Cron::Describe->new(cron_str => '0 0 12 L * ?', type => 'quartz');
my ($valid, $errors) = $cron->is_valid;
ok($valid, 'Quartz last day of month') or diag explain $errors;

eval { Cron::Describe->new(cron_str => '0 0 * 15 * MON', type => 'standard') };
like($@, qr/.*both be specified/i, 'Standard dom and dow conflict');

done_testing;
