#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use JSON::MaybeXS qw(decode_json);
use File::Slurp qw(read_file);
use Try::Tiny;
use Cron::Describe;

# Load JSON test data with English descriptions
my @files = qw(basic_parsing.json);
my @test_data;
foreach my $file (@files) {
    my $json = read_file("t/data/$file");
    my $data = decode_json($json);
    push @test_data, grep { defined $_->{english} } @$data;
}

# Run tests
my $test_num = 0;
foreach my $test (@test_data) {
    $test_num++;
    my $expression = $test->{expression};
    my $utc_offset = $test->{utc_offset} // 0;
    my $english = $test->{english};

    subtest "Test $test_num: $expression" => sub {
        my $cron;
        try {
            $cron = Cron::Describe->new(expression => $expression, utc_offset => $utc_offset);
            is($cron->to_english, $english, "English description matches: $english");
        } catch {
            fail("Failed to create Cron::Describe object for $expression: $_");
        };
    };
}

done_testing();
