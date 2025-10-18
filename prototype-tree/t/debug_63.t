use strict;
use warnings;
use Test::More;
use Cron::Describe;
use Data::Dumper;
use Cron::Describe::Tree::Utils qw(:all);

# TEST 63: 0 15 6 ? * 1#2 *
my $cron = Cron::Describe->new(expression => '0 15 6 ? * 1#2 *');
my @fields = @{$cron->{root}{children}};

# DEBUG: PRINT TREE STRUCTURE
diag "=== TREE DEBUG ===";
diag "SEC FIELD[0]: ", Dumper($fields[0]);
diag "MIN FIELD[1]: ", Dumper($fields[1]);
diag "HOUR FIELD[2]: ", Dumper($fields[2]);

# DEBUG: EXTRACTION VALUES
my $sec  = $fields[0]{value} // $fields[0]{children}[0]{value} // 0;
my $min  = $fields[1]{value} // $fields[1]{children}[0]{value} // 0;
my $hour = $fields[2]{value} // $fields[2]{children}[0]{value} // 0;

diag "=== EXTRACTION DEBUG ===";
diag "SEC RAW:  $sec";
diag "MIN RAW:  $min"; 
diag "HOUR RAW: $hour";
diag "format_time: ", format_time($sec, $min, $hour);

# TEST
is($cron->describe, 'at 6:15:00 AM on the second Sunday of every month', 'Test 63');
done_testing;
