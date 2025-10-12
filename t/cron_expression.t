#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Deep;
use JSON::MaybeXS;
use File::Slurp;
use Try::Tiny;
use lib 'lib';
use Cron::Describe;

# Load test data
my $basic_parsing = decode_json(read_file('t/data/basic_parsing.json'));
my $edge_cases = decode_json(read_file('t/data/edge_cases.json'));
my $matching = decode_json(read_file('t/data/matching.json'));
my $quartz_tokens = decode_json(read_file('t/data/quartz_tokens.json'));

# Combine all tests
my @all_tests = (@$basic_parsing, @$edge_cases, @$matching, @$quartz_tokens);
my $test_number = 0;

foreach my $test (@all_tests) {
    $test_number++;
    subtest "Test $test_number: $test->{expression}" => sub {
        my $desc;
        try {
            $desc = Cron::Describe->new($test->{expression}, utc_offset => $test->{utc_offset} // 0);
            if ($test->{is_valid}) {
                ok($desc->is_valid, "Cron expression is valid");
            } else {
                ok(!$desc->is_valid, "Cron expression is invalid");
            }
        } catch {
            ok(!$test->{is_valid}, "Cron expression is invalid");
            like($_, qr/$test->{error_message}/, "Error message matches: $test->{error_message}") if $test->{error_message};
        };

        if ($test->{is_valid} && $test->{expected_fields} && defined $desc) {
            cmp_deeply($desc->to_hash, $test->{expected_fields}, "Fields match expected structure");
        }

        if ($test->{matches} && defined $desc) {
            foreach my $match (@{$test->{matches}}) {
                my $tm = Time::Moment->from_epoch($match->{timestamp});
                is($desc->is_match($tm), $match->{matches}, "Match test for timestamp $match->{timestamp}");
            }
        }
    };
}

done_testing();
