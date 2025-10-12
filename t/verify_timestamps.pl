#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Deep;
use JSON::MaybeXS;
use File::Slurp;
use Try::Tiny;
use Time::Moment;
use lib 'lib';
use Cron::Describe;

# Load test data files
my @json_files = (
    't/data/basic_parsing.json',
    't/data/edge_cases.json',
    't/data/matching.json',
    't/data/quartz_tokens.json'
);

my $test_number = 0;
my @all_tests;

# Load and combine all test cases
foreach my $file (@json_files) {
    try {
        my $data = decode_json(read_file($file));
        push @all_tests, @$data;
    } catch {
        diag "Failed to load $file: $_";
        fail "Loading JSON file $file";
    };
}

# Filter tests with matches arrays
my @match_tests = grep { exists $_->{matches} && @{ $_->{matches} } } @all_tests;

foreach my $test (@match_tests) {
    $test_number++;
    subtest "Test $test_number: $test->{expression}" => sub {
        my $desc;
        try {
            $desc = Cron::Describe->new($test->{expression}, utc_offset => $test->{utc_offset} // 0);
            ok($desc->is_valid, "Cron expression is valid") if $test->{is_valid};
            ok(!$desc->is_valid, "Cron expression is invalid") unless $test->{is_valid};
        } catch {
            ok(!$test->{is_valid}, "Cron expression is invalid");
            like($_, qr/$test->{error_message}/, "Error message matches: $test->{error_message}") if $test->{error_message};
        };

        SKIP: {
            skip "Skipping match tests for invalid expression", 1 unless $desc && $desc->is_valid;
            foreach my $match (@{$test->{matches}}) {
                # Create Time::Moment with utc_offset applied
                my $tm = Time::Moment->from_epoch($match->{timestamp})->with_offset_same_instant($test->{utc_offset} // 0);
                my $result = $desc->is_match($tm);
                is($result, $match->{matches}, 
                   sprintf("Timestamp %s (%s) matches expected: %d", 
                           $match->{timestamp}, $tm->strftime('%Y-%m-%d %H:%M:%S %z'), $match->{matches}));
            }
        }
    };
}

done_testing();
