# File: t/dump_structures.t
use strict;
use warnings;
use Test::More;
use Data::Dumper;
use Cron::Describe;
use Cron::Describe::Quartz;

plan tests => 3;  # One test per expression

my @expressions = (
    '0 0 0 * * ?',           # Every day at midnight (Quartz)
    '0 0 0 1-5,10-15/2 * ?', # Days 1-5 and every other day from 10-15 (Quartz)
    '0 0 1 * *',            # Standard cron: every day at midnight
);

foreach my $expr (@expressions) {
    diag "Dumping structure for expression: $expr";
    my $cron = Cron::Describe->new(expression => $expr, debug => 1);
    diag "Parsed fields:\n", Dumper($cron->{fields});
    pass("Parsed $expr");
}

done_testing();
