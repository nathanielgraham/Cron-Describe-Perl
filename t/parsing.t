#!/usr/bin/env perl
use strict;
use warnings;
use Test::More 0.88;
use Cron::Toolkit;
eval { require JSON::MaybeXS };
plan skip_all => "JSON::MaybeXS required" if $@;
open my $fh, '<', 't/data/cron_tests.json' or BAIL_OUT("JSON missing");
my $json = do { local $/; <$fh> };
my @tests = @{ JSON::MaybeXS->new->decode($json) };
my @valid = grep { $_->{category} eq 'general' && !$_->{invalid} } @tests;
my @invalids = grep { $_->{invalid} } @tests;
subtest 'new() Builds & Normalizes' => sub {
    plan tests => scalar(@valid) * (2 + 2);
    for my $test (@valid) {
        my $cron = Cron::Toolkit->new(expression => $test->{expr});
        ok($cron, "Builds: $test->{expr}");
        is($cron->as_string, $test->{norm}, "Norm: $test->{norm}");
        is($test->{type}, ($test->{expr} =~ /^@/ ? 'alias' : 'quartz'), "Type: $test->{type}");
        if ($test->{tz}) {
            $cron->time_zone($test->{tz});
            is($cron->time_zone, $test->{tz}, "TZ: $test->{tz}");
        } elsif ($test->{utc_offset}) {
            $cron->utc_offset($test->{utc_offset});
            is($cron->utc_offset, $test->{utc_offset}, "Offset: $test->{utc_offset}");
        } else {
            pass("No TZ/offset for $test->{expr}");
        }
    }
};
subtest 'Unix/Quartz Constructors' => sub {
    plan tests => scalar(@valid);
    for my $test (@valid) {
        my @fields = split /\s+/, $test->{expr};
        if (scalar(@fields) == 5 && $test->{expr} !~ /^@/ && $test->{expr} !~ /\?/) {
            my $unix = Cron::Toolkit->new(expression => $test->{expr});
            is($unix->as_string, $test->{norm}, "new: $test->{expr}");
        } else {
            my $quartz = Cron::Toolkit->new_from_quartz(expression => $test->{norm});
            is($quartz->as_string, $test->{norm}, "new_from_quartz: $test->{norm}");
        }
    }
};
subtest 'Invalid Parsing' => sub {
    plan tests => scalar(@invalids) || 1;
    if (@invalids) {
        for my $test (@invalids) {
            local $@;
            eval { Cron::Toolkit->new(expression => $test->{expr}); 1 };
            my $err = $@;
            $err =~ s/ at .*//s if $err;
            like($err, qr/\Q$test->{expect_error}\E/, "Rejects: $test->{expr}");
        }
    } else {
        pass("No invalids in JSON");
    }
};
subtest 'new_from_crontab' => sub {
    plan tests => 4;
    my $crontab = <<'EOF';
SHELL=/bin/bash
# Comment
0 0 * * * root /bin/echo daily
0 0 * * * user2 /tmp/hourly
EOF
    my @crons = Cron::Toolkit->new_from_crontab($crontab);
    is(scalar(@crons), 2, "Parses 2 valid lines");
    is($crons[0]->user, 'root', "User: root");
    is($crons[0]->command, '/bin/echo daily', "Command: daily");
    is($crons[1]->as_string, '0 0 0 * * ? *', "Second line norm");
};
done_testing;
