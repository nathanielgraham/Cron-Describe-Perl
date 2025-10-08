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
    use_ok('Cron::Describe::CronExpression');
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
        for my $test (@$data) {
            my $test_name = $test->{name} || $test->{description} || $test->{expression};
            subtest $test_name => sub {
                my $expr;
                my $error = '';

                diag "Creating CronExpression for '$test->{expression}'";
                try {
                    $expr = Cron::Describe::CronExpression->new($test->{expression});
                    diag "Created object: " . ref($expr);
                } catch {
                    $error = $_;
                    $error =~ s/ at \S+ line \d+\.\n?$//;
                    diag "Caught error: $error";
                };

                if ($test->{is_valid}) {
                    if (!defined $expr) {
                        fail("Failed to create valid CronExpression object for '$test->{expression}': " . ($error || 'No error message'));
                        return;
                    }
                    ok(defined $expr, "Created CronExpression object for '$test->{expression}'");
                    is($expr->is_valid, 1, "Expression validates correctly");

                    if ($test->{expected_class}) {
                        my $is_quartz = ($test->{expression} =~ /\S+\s+\S+\s+\S+\s+\S+\s+\S+\s+\S+/);
                        is($is_quartz ? ref($expr) : 'Cron::Describe::CronExpression', 
                           $test->{expected_class}, 
                           "Correct class: $test->{expected_class}");
                    }

                    if ($test->{fields} || $test->{expected_fields}) {
                        my $expected_fields = $test->{fields} || $test->{expected_fields};
                        my @fields = @{$expr->fields};
                        cmp_deeply(\@fields, $expected_fields, "Fields parsed correctly");
                    }

                    if ($test->{matches}) {
                        for my $match (@{$test->{matches}}) {
                            my $tm = Time::Moment->from_string($match->{timestamp});
                            diag "DEBUG: Testing timestamp $match->{timestamp}, expected match: $match->{matches}";
                            is($expr->is_match($tm), $match->{matches}, "Match test: $match->{timestamp}");
                        }
                    } elsif ($test->{extras}) {
                        print STDERR "DEBUG: Extras for '$test->{expression}': " . encode_json($test->{extras}) . "\n";
                        for my $extra (@{$test->{extras}}) {
                            my $tm = Time::Moment->from_epoch($extra->{epoch});
                            diag "DEBUG: Testing epoch $extra->{epoch} ($tm), expected match: $extra->{matches}";
                            is($expr->is_match($tm), $extra->{matches}, "Match test: $extra->{desc}");
                        }
                    }
                } else {
                    ok(!defined $expr, "Correctly rejected invalid expression '$test->{expression}'");
                    my $expected_error = $test->{error_message};
                    print STDERR "DEBUG: Testing error message: actual='" . unpack("H*", $error) . "', expected='" . unpack("H*", $expected_error) . "'\n";
                    is($error, $expected_error, "Error message matches: $test->{error_message}");
                }
            };
        }
    };
}

done_testing();
