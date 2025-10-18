use strict;
use warnings;
use Test::More;
use Cron::Describe;

my @tests = (
    { expr => '0 */15 * * * ? *', field => 1, expected_type => 'step', expected_value => undef, expected_children => 2, expected_step_value => '15', english => 'every 15 minutes' },
    { expr => '0 0 0 1-5 * ? *', field => 3, expected_type => 'range', expected_value => undef, expected_children => 2, expected_step_value => undef, english => 'at midnight on the 1st through 5th of every month' },
    { expr => '0 0 0 * * 1,3,5 *', field => 5, expected_type => 'list', expected_value => undef, expected_children => 3, expected_step_value => undef, english => 'at midnight every Sunday, Tuesday, and Thursday' },
    { expr => '0 10-20/5 8 * * ? *', field => 1, expected_type => 'step', expected_value => undef, expected_children => 2, expected_step_value => '5', english => 'every 5 minutes from 10 to 20 past 8' },
    { expr => '0 0 0 L * ? *', field => 3, expected_type => 'last', expected_value => 'L', expected_children => 0, expected_step_value => undef, english => 'at midnight on the last day of every month' },
    { expr => '0 0 0 LW * ? *', field => 3, expected_type => 'lastW', expected_value => 'LW', expected_children => 0, expected_step_value => undef, english => 'at midnight on the last weekday of every month' },
    { expr => '0 0 0 ? * 1#3 *', field => 5, expected_type => 'nth', expected_value => '1#3', expected_children => 0, expected_step_value => undef, english => 'at midnight on the third Sunday of every month' },
    { expr => '0 0 0 * * ? 2025', field => 6, expected_type => 'single', expected_value => '2025', expected_children => 0, expected_step_value => undef, english => 'at midnight every day in 2025' },
    { expr => '*/5 * * ? * ? *', field => 0, expected_type => 'step', expected_value => undef, expected_children => 2, expected_step_value => '5', english => 'every 5 seconds' },
    { expr => '30 45 14 LW * ? *', field => 3, expected_type => 'lastW', expected_value => 'LW', expected_children => 0, expected_step_value => undef, english => 'at 2:45:30 PM on the last weekday of every month' },
    { expr => '15 30 9 ? * 1#1 *', field => 5, expected_type => 'nth', expected_value => '1#1', expected_children => 0, expected_step_value => undef, english => 'at 9:30:15 AM on the first Sunday of every month' },
    { expr => '0 15 6 ? * 1#2 *', field => 5, expected_type => 'nth', expected_value => '1#2', expected_children => 0, expected_step_value => undef, english => 'at 6:15:00 AM on the second Sunday of every month' },
);

for my $test (@tests) {
    eval {
        my $cron = Cron::Describe->new(expression => $test->{expr});
        ok(1, "Built: $test->{expr}");
        my @children = @{$cron->{root}->{children}};
        my $node = $children[$test->{field}];
        is($node->{type}, $test->{expected_type}, "Type for $test->{expr}: $test->{field}");
        is($node->{value}, $test->{expected_value}, "Value for $test->{expr}: $test->{field}");
        is(scalar @{$node->{children} || []}, $test->{expected_children}, "Children count for $test->{expr}: $test->{field}");
        if ($test->{expected_step_value}) {
            my $step_child = $node->{children}[1];
            is($step_child->{value}, $test->{expected_step_value}, "Step value for $test->{expr}");
        }
        is($cron->to_english, $test->{english}, "English for $test->{expr}");
    };
    if ($@) {
        fail("Built: $test->{expr}");
        diag "Error: $@";
    }
}

done_testing();
