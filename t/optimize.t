use strict;
use warnings;
use Test::More;
use Test::Exception;
use Cron::Toolkit::Tree::TreeParser;

my @tests = (
    {
        field => '7/2',
        type => 'dow',
        is_unix => 1,
        expected_type => 'single',
        expected_value => 1,
    },
    {
        field => '4-7',
        type => 'dow',
        is_unix => 1,
        expected_type => 'list',
        expected_children => 2,
        rebuilt => '1,5-7',
    },
    {
        field => '2,3,4,5',
        type => 'month',
        is_unix => 0,
        expected_type => 'range',
        expected_start => 2,
        expected_end => 5,
    },
    {
        field => '1,3,4,6',
        type => 'dom',
        is_unix => 0,
        expected_type => 'list',
        expected_children => 3,
        rebuilt => '1,3-4,6',
    },
    {
        field => '4-7/2',
        type => 'dow',
        is_unix => 1,  # Fixed from unix=0
        expected_type => 'list',
        expected_children => 2,
        rebuilt => '5,7',
    },
    {
        field => '58/3',
        type => 'second',
        is_unix => 0,
        expected_type => 'single',
        expected_value => 58,
    },
    {
        field => '6',
        type => 'dow',
        is_unix => 1,
        expected_type => 'single',
        expected_value => 7,
    },
    {
        field => 'L',
        type => 'dom',
        is_unix => 1,
        expected_type => 'last',
        expected_value => 'L',
    },
);

plan tests => scalar(@tests);

for my $test (@tests) {
    subtest "Optimize: $test->{field} ($test->{type}, unix=$test->{is_unix})" => sub {
        my $parser = Cron::Toolkit::Tree::TreeParser->new(is_quartz => !$test->{is_unix});
        my $node;
        lives_ok {
            $node = $parser->parse_field($test->{field}, $test->{type});
        } "Parse field $test->{field}";
        return unless $node;
        $node->dump_tree if $ENV{TEST_DEBUG};
        is($node->{type}, $test->{expected_type}, "Type");
        if ($test->{expected_type} eq 'single' || $test->{expected_type} eq 'nth' || $test->{expected_type} eq 'last') {
            is($node->{value}, $test->{expected_value}, "Value");
        } elsif ($test->{expected_type} eq 'range') {
            is($node->{children}[0]{value}, $test->{expected_start}, "Range start");
            is($node->{children}[1]{value}, $test->{expected_end}, "Range end");
        } elsif ($test->{expected_type} eq 'list') {
            is(scalar(@{$node->{children}}), $test->{expected_children}, "Children count");
            my $rebuilt = $parser->rebuild_from_node($node);
            is($rebuilt, $test->{rebuilt}, "Rebuilt string");
        }
    };
}

done_testing;
