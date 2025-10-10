#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Deep;
use JSON::MaybeXS;
use File::Slurp;
use Time::Moment;
use Try::Tiny;

# Load required modules
BEGIN {
    use_ok('Cron::Describe');
    use_ok('Cron::Describe::Pattern');
    use_ok('Cron::Describe::WildcardPattern');
    use_ok('Cron::Describe::UnspecifiedPattern');
    use_ok('Cron::Describe::SinglePattern');
    use_ok('Cron::Describe::RangePattern');
    use_ok('Cron::Describe::StepPattern');
    use_ok('Cron::Describe::ListPattern');
    use_ok('Cron::Describe::DayOfMonthPattern');
    use_ok('Cron::Describe::DayOfWeekPattern');
}

# Load JSON test data
my @json_files = (
    't/data/basic_parsing.json',
    't/data/quartz_tokens.json',
    't/data/matching.json',
    't/data/edge_cases.json'
);

foreach my $file (@json_files) {
    unless (-e $file) {
        diag "JSON file $file not found, skipping tests for this file";
        next;
    }
    my $json_content = read_file($file);
    my $data = decode_json($json_content);
    my $file_name = (split('/', $file))[-1];
    print STDERR "DEBUG: Loaded JSON file $file_name: " . substr($json_content, 0, 100) . "...\n";
    subtest "Tests from $file_name" => sub {
        my $test_count = 0;
        for my $test (@$data) {
            my $test_name = $test->{name} || $test->{description} || $test->{expression};
            subtest $test_name => sub {
                diag "Starting subtest: $test_name";
                my $expr;
                my $error = '';
                my $utc_offset = $test->{utc_offset} // 0;
                diag "Creating Cron::Describe for '$test->{expression}' with utc_offset=$utc_offset";
                try {
                    $expr = Cron::Describe->new(expression => $test->{expression}, utc_offset => $utc_offset);
                    diag "Created object: " . ref($expr);
                } catch {
                    $error = $_;
                    $error =~ s/ at \S+ line \d+\.\n?$//;
                    diag "Caught error: $error";
                };
                my $subtest_count = $test->{is_valid} ? ($test->{fields} || $test->{expected_fields} ? 3 : 2) : 2;
                $subtest_count += scalar(@{$test->{matches} || []}) if $test->{matches};
                $subtest_count += scalar(@{$test->{extras} || []}) if $test->{extras};
                diag "Expected $subtest_count tests for subtest '$test_name'";
                if ($test->{is_valid}) {
                    unless (defined $expr) {
                        fail("Failed to create valid Cron::Describe object for '$test->{expression}': " . ($error || 'No error message'));
                        return;
                    }
                    ok(defined $expr, "Created Cron::Describe object for '$test->{expression}'");
                    is($expr->is_valid, 1, "Expression validates correctly");
                    if ($test->{fields} || $test->{expected_fields}) {
                        my $expected_fields = $test->{fields} || $test->{expected_fields};
                        my @fields = @{$expr->fields};
                        cmp_deeply(\@fields, $expected_fields, "Fields parsed correctly");
                    }
                    if ($test->{matches}) {
                        for my $match (@{$test->{matches}}) {
                            my $seconds = $match->{timestamp};
                            diag "DEBUG: Testing timestamp $seconds, expected match: $match->{matches}";
                            is($expr->is_match($seconds), $match->{matches}, "Match test: $seconds");
                        }
                    } elsif ($test->{extras}) {
                        print STDERR "DEBUG: Extras for '$test->{expression}': " . encode_json($test->{extras}) . "\n";
                        for my $extra (@{$test->{extras}}) {
                            my $seconds = $extra->{epoch};
                            diag "DEBUG: Testing epoch $extra->{epoch} ($seconds), expected match: $extra->{matches}";
                            is($expr->is_match($seconds), $extra->{matches}, "Match test: $extra->{desc}");
                        }
                    }
                } else {
                    ok(!defined $expr, "Correctly rejected invalid expression '$test->{expression}'");
                    my $expected_error = $test->{error_message};
                    print STDERR "DEBUG: Testing error message: actual='" . unpack("H*", $error) . "', expected='" . unpack("H*", $expected_error) . "'\n";
                    is($error, $expected_error, "Error message matches: $test->{error_message}");
                }
                diag "Finished subtest: $test_name";
                $test_count += $subtest_count;
            };
        }
        diag "Total tests executed for $file_name: $test_count";
    };
}

subtest 'Normalization and Offset Tests' => sub {
    my @tests = (
        {
            input => '0 0 1 * *',
            normalized => '0 0 0 1 * ? *',
            utc_offset => 0,
            timestamp => 1759276800,
            matches => 1,
            desc => 'Standard cron with unspecified dow, matches 2025-10-01T00:00:00Z'
        },
        {
            input => '0 0 0 * JAN ?',
            normalized => '0 0 0 * 1 ? *',
            utc_offset => 0,
            desc => 'Quartz with extra whitespace and month name'
        },
        {
            input => '0 0 0 L FEB ? 2024',
            normalized => '0 0 0 L 2 ? 2024',
            utc_offset => -300,
            desc => 'Quartz with month name and year, matches last day of February 2024 in America/New_York'
        }
    );
    for my $test (@tests) {
        subtest $test->{desc} => sub {
            diag "Starting normalization subtest: $test->{desc}";
            my $expr;
            my $error = '';
            try {
                $expr = Cron::Describe->new(expression => $test->{input}, utc_offset => $test->{utc_offset});
            } catch {
                $error = $_;
                $error =~ s/ at \S+ line \d+\.\n?$//;
                diag "Caught error: $error";
                fail("Failed to normalize '$test->{input}': $error");
                return;
            };
            unless (defined $expr) {
                fail("Cron::Describe object is undefined for '$test->{input}'");
                return;
            }
            my @fields = map { $_->to_string } @{$expr->{fields}};
            is(join(' ', @fields), $test->{normalized}, "Normalization: $test->{input} -> $test->{normalized}");
            if (defined $test->{timestamp}) {
                is($expr->is_match($test->{timestamp}), $test->{matches}, "Match test: $test->{timestamp}");
            }
            diag "Finished normalization subtest: $test->{desc}";
        };
    }
    subtest 'Offset-aware matching' => sub {
        diag "Starting offset-aware matching subtest";
        my $expr;
        my $error = '';
        try {
            $expr = Cron::Describe->new(expression => '0 0 0 1 * ?', utc_offset => -300);
        } catch {
            $error = $_;
            $error =~ s/ at \S+ line \d+\.\n?$//;
            diag "Caught error: $error";
            fail("Failed to create Cron::Describe object: $error");
            return;
        };
        unless (defined $expr) {
            fail("Cron::Describe object is undefined");
            return;
        }
        my $tm_nyc = Time::Moment->from_string('2025-10-01T00:00:00-05:00', lenient => 1);
        my $tm_utc = Time::Moment->from_string('2025-10-01T00:00:00Z', lenient => 1);
        is($expr->is_match($tm_nyc->epoch), 1, "Matches at midnight with -300 offset");
        is($expr->is_match($tm_utc->epoch), 0, "Does not match at midnight UTC");
        diag "Finished offset-aware matching subtest";
    };
    subtest 'Invalid Offset' => sub {
        diag "Starting invalid offset subtest";
        my $error;
        try {
            Cron::Describe->new(expression => '0 0 0 1 * ?', utc_offset => 1000);
        } catch {
            $error = $_;
            $error =~ s/ at \S+ line \d+\.\n?$//;
        };
        is($error, "Invalid utc_offset: must be an integer between -720 and 720 minutes", "Rejects invalid offset");
        diag "Finished invalid offset subtest";
    };
    subtest 'Invalid Epoch Seconds' => sub {
        diag "Starting invalid epoch seconds subtest";
        my $expr;
        my $error = '';
        try {
            $expr = Cron::Describe->new(expression => '0 0 0 1 * ?', utc_offset => 0);
        } catch {
            $error = $_;
            $error =~ s/ at \S+ line \d+\.\n?$//;
            diag "Caught error: $error";
            fail("Failed to create Cron::Describe object: $error");
            return;
        };
        unless (defined $expr) {
            fail("Cron::Describe object is undefined");
            return;
        }
        try {
            $expr->is_match(-1);
        } catch {
            $error = $_;
            $error =~ s/ at \S+ line \d+\.\n?$//;
        };
        is($error, "Invalid epoch seconds: must be a non-negative integer", "Rejects negative epoch seconds");
        try {
            $expr->is_match('abc');
        } catch {
            $error = $_;
            $error =~ s/ at \S+ line \d+\.\n?$//;
        };
        is($error, "Invalid epoch seconds: must be a non-negative integer", "Rejects non-integer epoch seconds");
        diag "Finished invalid epoch seconds subtest";
    };
};

done_testing();
