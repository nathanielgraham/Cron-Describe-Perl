#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 0.88;
use Cron::Toolkit;
use Cron::Toolkit::Tree::TreeParser;
use Cron::Toolkit::Tree::MatchVisitor;

eval { require JSON::MaybeXS };
plan skip_all => "JSON::MaybeXS required" if $@;

open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("JSON missing");
my $json = do { local $/; <$fh> };
my @tests = @{ JSON::MaybeXS->new->decode($json) };

my @valid = grep { !$_->{invalid} } @tests;
plan tests => scalar(@valid) * 3 + 8;  # Parse per field, root build, visitor match + basics

subtest 'TreeParser::parse_field' => sub {
    plan tests => scalar(@valid) * 2;
    for my $test (@valid) {
        my @fields = split /\s+/, $test->{expr};
        for my $i (0..$#fields) {
            my $field_type = qw(second minute hour dom month dow year)[$i % 7];
            my $node = Cron::Toolkit::Tree::TreeParser->parse_field($fields[$i], $field_type);
            ok($node, "Parses $fields[$i] as $field_type");
            # Basic type (expand JSON with "ast" for per-field)
            my $type = $node->{type} // 'wildcard';
            ok($type ne '', "Type: $type");
            if ($fields[$i] =~ /^\d+$/) {
                is($type, 'single', "Single for $fields[$i]");
            } elsif ($fields[$i] =~ /,/) {
                is($type, 'list', "List for $fields[$i]");
            }
        }
    }
};

subtest 'AST in new()' => sub {
    plan tests => scalar(@valid);
    for my $test (@valid) {
        my $cron = Cron::Toolkit->new(expression => $test->{expr});
        my $root = $cron->{root};
        ok(ref $root eq 'Cron::Toolkit::Tree::CompositePattern', "Root composite");
        is(scalar(@{$root->{children}}), 7, "7 children");
        # Example: Hour field (index 2) for '14' exprs
        if ($test->{expr} =~ /14/) {
            my $hour_node = $root->{children}[2];
            is($hour_node->{type}, 'single', "Hour single");
            is($hour_node->{value}, 14, "Value 14");
        }
    }
};

subtest 'MatchVisitor Isolation' => sub {
    plan tests => 8;
    # Step example from JSON
    my $step = Cron::Toolkit::Tree::TreeParser->parse_field('*/15', 'second');
    my $visitor10 = Cron::Toolkit::Tree::MatchVisitor->new(value => 15);
    is($step->traverse($visitor10), 1, "Step */15 matches 15");
    my $visitor7 = Cron::Toolkit::Tree::MatchVisitor->new(value => 7);
    is($step->traverse($visitor7), 0, "Rejects 7");

    # Single
    my $single = Cron::Toolkit::Tree::TreeParser->parse_field('30', 'minute');
    is($single->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 30)), 1, "Single 30 matches");
    is($single->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 31)), 0, "Rejects 31");

    # Range (from JSON '10-14')
    my $range = Cron::Toolkit::Tree::TreeParser->parse_field('10-14', 'hour');
    is($range->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 12)), 1, "Range 10-14 matches 12");
    is($range->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 9)), 0, "Rejects 9");

    # Last (L)
    my $last = Cron::Toolkit::Tree::TreeParser->parse_field('L', 'dom');
    # Mock TM for Oct 31, 2025 (length 31)
    my $tm = Time::Moment->new(year => 2025, month => 10, day => 31);
    my $v_last = Cron::Toolkit::Tree::MatchVisitor->new(value => 31, tm => $tm);
    is($last->traverse($v_last), 1, "L matches last day");
};

subtest 'dump_tree' => sub {
    plan tests => 1;
    my $cron = Cron::Toolkit->new(expression => '0 30 14 * * ?');
    local *STDOUT;
    open my $out, '>', \my $buf;
    *STDOUT = $out;
    $cron->dump_tree;
    close $out;
    like($buf, qr/Root/, "Dumps AST");
};

done_testing;
