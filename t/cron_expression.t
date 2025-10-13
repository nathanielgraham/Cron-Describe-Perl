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

# Load and combine all test data
my @json_files = qw(t/data/basic_parsing.json t/data/edge_cases.json t/data/matching.json t/data/quartz_tokens.json);
my @all_tests;
foreach my $file (@json_files) {
    try {
        my $data = decode_json(read_file($file));
        push @all_tests, @$data;
    } catch {
        diag "Failed to load $file: $_";
        fail "Loading JSON file $file";
    };
}

# Cache for Time::Moment objects
my %time_moment_cache;

# Validate test data
foreach my $test (@all_tests) {
    unless (exists $test->{expression} && defined $test->{expression}) {
        diag "Test data missing 'expression' field";
        fail "Invalid test data: missing expression";
    }
    unless (exists $test->{is_valid}) {
        diag "Test data missing 'is_valid' field for expression: $test->{expression}";
        fail "Invalid test data: missing is_valid";
    }
}

# Test functions
sub test_validation {
    my ($desc, $test) = @_;
    my $is_valid = $desc ? $desc->is_valid : 0;
    my $error_message = $desc ? $desc->error_message : $_;
    my $ok = ok($is_valid == $test->{is_valid}, 
                $test->{is_valid} ? "Cron expression is valid" : "Cron expression is invalid");
    if (!$ok && $error_message) {
        diag "Error: $error_message";
        like($error_message, qr/$test->{error_message}/, "Error message matches: $test->{error_message}")
            if $test->{error_message};
    }
    return $ok;
}

sub test_fields {
    my ($desc, $test) = @_;
    cmp_deeply($desc->to_hash, $test->{expected_fields}, "Fields match expected structure");
}

sub test_matches {
    my ($desc, $test) = @_;
    foreach my $match (@{$test->{matches}}) {
        my $ts = $match->{timestamp};
        $time_moment_cache{$ts} //= Time::Moment->from_epoch($ts);
        my $tm = $time_moment_cache{$ts};
        is($desc->is_match($tm), $match->{matches},
           sprintf("Timestamp %s (%s) matches expected: %d",
                   $ts, $tm->strftime('%Y-%m-%d %H:%M:%S %z'), $match->{matches}));
    }
}

# Run tests
my $test_number = 0;
foreach my $test (@all_tests) {
    $test_number++;
    my $test_desc = $test->{description} // ($test->{is_valid} ? "Valid cron: $test->{expression}" : "Invalid cron: $test->{expression}");
    subtest "Test $test_number: $test_desc" => sub {
        my $desc;
        my $exception;
        try {
            $desc = Cron::Describe->new($test->{expression}, utc_offset => $test->{utc_offset} // 0);
        } catch {
            $exception = $_;
        };

        # Consolidated diagnostic
        my $diag_msg = "Test Summary:\n";
        $diag_msg .= "  Original expression: $test->{expression}\n";
        $diag_msg .= "  Normalized expression: " . ($desc ? $desc->to_string : "N/A (failed to parse)") . "\n";
        $diag_msg .= "  Status: " . ($desc && $desc->is_valid ? "Valid" : "Invalid") . "\n";
        $diag_msg .= "  Error: " . ($exception ? $exception : ($desc && $desc->error_message ? $desc->error_message : "None")) . "\n";
        $diag_msg .= "  Expected: " . ($test->{is_valid} ? "Valid" : "Invalid") . "\n";
        diag $diag_msg;

        # Validation test
        my $validation_passed = test_validation($desc, $test);

        # Skip further tests if validation failed or expression is invalid
        SKIP: {
            skip "Skipping field and match tests for invalid expression", 2 unless $validation_passed && $desc && $desc->is_valid;
            
            # Field structure test
            if ($test->{expected_fields}) {
                test_fields($desc, $test);
            } else {
                pass("No expected fields to test");
            }

            # Timestamp matching test
            if ($test->{matches} && @{$test->{matches}}) {
                test_matches($desc, $test);
            } else {
                pass("No match tests defined");
            }
        }
    };
}

done_testing();
