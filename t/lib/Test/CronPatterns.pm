package Test::CronPatterns;
use strict;
use warnings;
use Test::More;
use JSON;
use File::Spec;
use Time::Moment;
use Cron::Describe;
use Cron::Describe::Quartz;
use Cron::Describe::Standard;
use Exporter 'import';
our @EXPORT = qw(run_tests);

sub run_tests {
    my ($test_name, %options) = @_;
    my $json_file = File::Spec->catfile('t', 'data', "$test_name.json");
    open my $fh, '<', $json_file or die "Cannot open $json_file: $!";
    my $json_text = do { local $/; <$fh> };
    close $fh;
    my $test_data = decode_json($json_text);

    foreach my $test (@$test_data) {
        subtest $test->{description} => sub {
            # Test with factory constructor
            my $cron = Cron::Describe->new(
                expression => $test->{expression},
                debug => 1
            );
            is(ref($cron), $test->{expected_class} || 'Cron::Describe::Quartz', "Auto-detection returns correct class for $test->{description}");
            is_deeply($cron->{fields}, $test->{fields}, "Parsed fields match expected structure");
            is($cron->is_valid, $test->{is_valid}, "is_valid");

            # Test with explicit constructor
            my $expected_class = $test->{expected_class} || 'Cron::Describe::Quartz';
            if ($expected_class eq 'Cron::Describe::Quartz') {
                my $quartz_cron = Cron::Describe::Quartz->new(
                    expression => $test->{expression},
                    debug => 1
                );
                is(ref($quartz_cron), 'Cron::Describe::Quartz', "Explicit Quartz constructor returns Quartz object");
                is_deeply($quartz_cron->{fields}, $test->{fields}, "Explicit Quartz constructor: Parsed fields match");
                is($quartz_cron->is_valid, $test->{is_valid}, "Explicit Quartz constructor: is_valid");
            } elsif ($expected_class eq 'Cron::Describe::Standard') {
                my $std_cron = Cron::Describe::Standard->new(
                    expression => $test->{expression},
                    debug => 1
                );
                is(ref($std_cron), 'Cron::Describe::Standard', "Explicit Standard constructor returns Standard object");
                is_deeply($std_cron->{fields}, $test->{fields}, "Explicit Standard constructor: Parsed fields match");
                is($std_cron->is_valid, $test->{is_valid}, "Explicit Standard constructor: is_valid");
            }

            # Test matches if present
            if (exists $test->{matches}) {
                foreach my $match (@{$test->{matches}}) {
                    my $tm = Time::Moment->from_string($match->{timestamp}, lenient => 1);
                    is($cron->is_match($tm->epoch), $match->{matches}, "Matches timestamp for $test->{description}: $match->{timestamp}");
                }
            }

            # Test English description if present
            if (exists $test->{english}) {
                is($cron->to_english, $test->{english}, "English description for $test->{description}");
            }
        };
    }

    # Test invalid 5-field Quartz expression
    if ($options{test_invalid}) {
        eval {
            my $cron = Cron::Describe->new(expression => '0 0 1 * ?', debug => 1);
        };
        like($@, qr/Invalid 5-field expression with Quartz-specific tokens/, "Rejects 5-field Quartz expression");
    }

    # Test standard cron if specified
    if ($options{test_standard}) {
        my $std_test = {
            description => "Standard cron: every day at midnight",
            expression => "0 0 1 * *",
            fields => [
                {
                    field_type => "minute",
                    pattern_type => "single",
                    value => 0,
                    min_value => 0,
                    max_value => 0,
                    step => 1,
                    min => 0,
                    max => 59
                },
                {
                    field_type => "hour",
                    pattern_type => "single",
                    value => 0,
                    min_value => 0,
                    max_value => 0,
                    step => 1,
                    min => 0,
                    max => 23
                },
                {
                    field_type => "dom",
                    pattern_type => "single",
                    value => 1,
                    min_value => 1,
                    max_value => 1,
                    step => 1,
                    min => 1,
                    max => 31
                },
                {
                    field_type => "month",
                    pattern_type => "wildcard",
                    min => 1,
                    max => 12
                },
                {
                    field_type => "dow",
                    pattern_type => "wildcard",
                    min => 0,
                    max => 7
                }
            ],
            is_valid => 1,
            english => "Runs at 00:00, on day 1 of month, in every month, every day-of-week",
            expected_class => "Cron::Describe::Standard"
        };
        subtest $std_test->{description} => sub {
            my $cron = Cron::Describe->new(
                expression => $std_test->{expression},
                debug => 1
            );
            is(ref($cron), $std_test->{expected_class}, "Auto-detection returns Standard object");
            is_deeply($cron->{fields}, $std_test->{fields}, "Parsed fields match expected structure");
            is($cron->is_valid, $std_test->{is_valid}, "is_valid");
            is($cron->to_english, $std_test->{english}, "English description");

            my $std_cron = Cron::Describe::Standard->new(
                expression => $std_test->{expression},
                debug => 1
            );
            is(ref($std_cron), 'Cron::Describe::Standard', "Explicit Standard constructor returns Standard object");
            is_deeply($std_cron->{fields}, $std_test->{fields}, "Explicit Standard constructor: Parsed fields match");
            is($std_cron->is_valid, $std_test->{is_valid}, "Explicit Standard constructor: is_valid");
        };
    }
}

1;
