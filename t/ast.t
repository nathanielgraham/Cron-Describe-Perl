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
plan tests => scalar(@valid) * 3 + 8;
subtest 'TreeParser::parse_field' => sub {
    plan tests => scalar(@valid) * 3;
    for my $test (@valid) {
        my @fields = split /\s+/, $test->{expr};
        for my $i (0..$#fields) {
            my $field_type = qw(second minute hour dom month dow year)[$i % 7];
            my $parser = Cron::Toolkit::Tree::TreeParser->new(
                is_quartz => !(scalar(@fields) == 5 && $test->{expr} !~ /^@/ && $test->{expr} !~ /\?/)
            );
            my $node = $parser->parse_field($fields[$i], $field_type);
            ok($node, "Parses $fields[$i] as $field_type");
            my $type = $node->{type} // 'wildcard';
            ok($type ne '', "Type: $type");
            if ($field_type eq 'dow' && scalar(@fields) == 5 && $test->{expr} !~ /^@/ && $test->{expr} !~ /\?/) {
                if ($fields[$i] eq '4-7') {
                    is($type, 'list', "List for 4-7 (dow, unix)");
                    is($parser->rebuild_from_node($node), '1,5-7', "Rebuilt: 1,5-7");
                } elsif ($fields[$i] eq '4-7/2') {
                    is($type, 'list', "List for 4-7/2 (dow, unix)");
                    is($parser->rebuild_from_node($node), '5,7', "Rebuilt: 5,7");
                } elsif ($fields[$i] eq '7/2') {
                    is($type, 'single', "Single for 7/2 (dow, unix)");
                    is($node->{value}, '1', "Value: 1");
                } elsif ($fields[$i] eq '6') {
                    is($type, 'single', "Single for 6 (dow, unix)");
                    is($node->{value}, '7', "Value: 7");
                } elsif ($fields[$i] eq '5-1') {
                    is($type, 'list', "List for 5-1 (dow, unix)");
                    is($parser->rebuild_from_node($node), '1,6-7', "Rebuilt: 1,6-7");
                } elsif ($fields[$i] eq '1-5/2') {
                    is($type, 'list', "List for 1-5/2 (dow, unix)");
                    is($parser->rebuild_from_node($node), '2,4,6', "Rebuilt: 2,4,6");
                } elsif ($fields[$i] =~ /^(MON|SUN)$/i) {
                    my $expected = $fields[$i] =~ /SUN/i ? '1' : '2';
                    is($type, 'single', "Single for $fields[$i] (dow, unix)");
                    is($node->{value}, $expected, "Value: $expected");
                } elsif ($fields[$i] eq 'mOn,WeD,fRi') {
                    is($type, 'list', "List for mOn,WeD,fRi (dow, unix)");
                    is($parser->rebuild_from_node($node), '2,4,6', "Rebuilt: 2,4,6");
                }
            } elsif ($fields[$i] =~ /^\d+$/) {
                is($type, 'single', "Single for $fields[$i]");
            } elsif ($fields[$i] =~ /,/) {
                is($type, 'list', "List for $fields[$i]");
            } elsif ($fields[$i] =~ /\-/) {
                is($type, 'range', "Range for $fields[$i]");
            } elsif ($fields[$i] =~ /\/[1-9]/) {
                is($type, 'step', "Step for $fields[$i]");
            } elsif ($fields[$i] eq 'L') {
                is($type, 'last', "Last for $fields[$i]");
            }
        }
    }
};
subtest 'AST in new()' => sub {
    plan tests => scalar(@valid) * 3;
    for my $test (@valid) {
        my $cron = Cron::Toolkit->new(expression => $test->{expr});
        my $root = $cron->{root};
        ok(ref $root eq 'Cron::Toolkit::Tree::CompositePattern', "Root composite");
        is(scalar(@{$root->{children}}), 7, "7 children");
        if ($test->{expr} =~ /14/) {
            my $hour_node = $root->{children}[2];
            is($hour_node->{type}, 'single', "Hour single");
            is($hour_node->{value}, 14, "Value 14");
        }
    }
};
subtest 'MatchVisitor Isolation' => sub {
    plan tests => 8;
    my $step = Cron::Toolkit::Tree::TreeParser->parse_field('*/15', 'second');
    my $visitor10 = Cron::Toolkit::Tree::MatchVisitor->new(value => 15);
    is($step->traverse($visitor10), 1, "Step */15 matches 15");
    my $visitor7 = Cron::Toolkit::Tree::MatchVisitor->new(value => 7);
    is($step->traverse($visitor7), 0, "Rejects 7");
    my $single = Cron::Toolkit::Tree::TreeParser->parse_field('30', 'minute');
    is($single->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 30)), 1, "Single 30 matches");
    is($single->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 31)), 0, "Rejects 31");
    my $range = Cron::Toolkit::Tree::TreeParser->parse_field('10-14', 'hour');
    is($range->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 12)), 1, "Range 10-14 matches 12");
    is($range->traverse(Cron::Toolkit::Tree::MatchVisitor->new(value => 9)), 0, "Rejects 9");
    my $last = Cron::Toolkit::Tree::TreeParser->parse_field('L', 'dom');
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
