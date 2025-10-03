use strict;
use warnings;
use Test::More;
use JSON qw(decode_json);
use File::Slurp;
use Data::Dumper;
use Test::CronPatterns;
use Cron::Describe;

my $json_data = read_file('t/data/basic_parsing.json');
my @tests = @{decode_json($json_data)};

for my $test (@tests) {
    my $desc = $test->{description};
    subtest $desc => sub {
        my $cron;
        if ($test->{is_valid}) {
            $cron = Cron::Describe->new(expression => $test->{expression}, debug => 1);
            if ($desc =~ /Standard cron/) {
                is(ref($cron), 'Cron::Describe::Standard', "Auto-detection returns correct class for $desc");
            } else {
                is(ref($cron), 'Cron::Describe::Quartz', "Auto-detection returns correct class for $desc");
            }
            is_deeply($cron->{fields}, $test->{fields}, 'Parsed fields match expected structure');
            is($cron->is_valid, $test->{is_valid}, 'is_valid');
        }
        if ($desc !~ /Rejects/) {
            $cron = $desc =~ /Standard cron/ ?
                Cron::Describe::Standard->new(expression => $test->{expression}, debug => 1) :
                Cron::Describe::Quartz->new(expression => $test->{expression}, debug => 1);
            if ($desc =~ /Standard cron/) {
                is(ref($cron), 'Cron::Describe::Standard', "Explicit Standard constructor returns Standard object");
            } else {
                is(ref($cron), 'Cron::Describe::Quartz', "Explicit Quartz constructor returns Quartz object");
            }
            if ($test->{is_valid}) {
                is_deeply($cron->{fields}, $test->{fields}, 'Explicit constructor: Parsed fields match');
                is($cron->is_valid, $test->{is_valid}, 'Explicit constructor: is_valid');
                is($cron->to_english, $test->{english}, "English description for $desc");
            }
        } else {
            eval { Cron::Describe::Quartz->new(expression => $test->{expression}, debug => 1) };
            like($@, qr/Invalid number of fields/, "Rejects 5-field Quartz expression");
        }
    };
}

done_testing();
