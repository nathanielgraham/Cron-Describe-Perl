#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Cron::Toolkit;
use Time::Moment;
use JSON::MaybeXS;
use feature 'say';

# ----------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------
srand(time ^ $$);

my @common_tzs = qw(
    America/New_York
    Europe/London
    Asia/Tokyo
    Australia/Sydney
    America/Los_Angeles
    Europe/Paris
);

my @common_offsets = qw(-300 0 60 540 -480 120);

my $BASE        = Time::Moment->new(year => 2025, month => 10, day => 23);
my $FAR_FUTURE  = Time::Moment->new(year => 2031, month => 12, day => 31);
my $FAR_PAST    = Time::Moment->new(year => 1999, month => 1, day => 1);

# ----------------------------------------------------------------------
# Raw expressions: valid + invalid
# ----------------------------------------------------------------------
my @raw_exprs = (
    # Valid Unix
    '* * * * *',
    '* * * * MON,TUE,WED',
    '* * * * 7/2',
    '* * * * MON-FRI',
    '*/10 * * * *',
    '1-5 * * * *',
    '30 14 * * *',
    '30 14 * * 0',
    '30 14 * * 1-5/2',
    '30 14 * * 5-1',
    '30 14 * * MON',
    '30 14 * * SAT',
    '30 14 * * SUN',
    '30 14 * * mOn,WeD,fRi',
    '30 14 * JaN-MaR *',
    '30 14 * jan Mon',
    '30 14 1-15/5 * *',
    '@daily',
    '@hourly',
    '@yearly',

    # Valid Quartz
    '0 0 * * * ?',
    '0 0 * */31 * ? *',
    '0 0 */3 * * ? *',
    '0 0 0 * * ? *',
    '0 0 0 * * ? 2025',
    '0 0 0 * 11/3 ? *',
    '0 0 0 1 JAN ? *',
    '0 0 0 16W * ? *',
    '0 0 0 29 FEB ? *',
    '0 0 0 L * ? *',
    '0 0 0 L-2 * ? *',
    '0 0 0 LW * ? *',
    '0 0 10-14 * * ?',
    '0 30 14 * * ?',
    '0 30 14 * * ? 2025',
    '0 30 14 ? * 6',
    '0 30 14 ? * MON *',
    '*/15 * * * * ?',
    '0 0 0 * * 1#2 *',
    '0 0 0 * * 2W *',

    # Invalid
    '30 14 * JAN FOO',
    '30 14 * XYZ MON',
    '@bogus',
    '@monthly',
    '0 0 0 * * 1#2 ?',
    '0 0 0 * * 2 ?',
    '0 0 0 1,15 * * ?',
    'L * * * *',
    '0 0 0 * * ? ?',
    '* * * * 5-1',
    '* * * * 1,99',
);

# ----------------------------------------------------------------------
# Generate test data
# ----------------------------------------------------------------------
my @data;

for my $expr (@raw_exprs) {
    my ($tz, $offset_min) = (undef, 0);
    my $rand = rand();

    if ($rand > 0.25) {
        if ($rand < 0.75) {
            $tz = $common_tzs[int rand @common_tzs];
        } else {
            $offset_min = $common_offsets[int rand @common_offsets];
        }
    }

    eval {
        print STDERR "DEBUG: Processing '$expr'\n" if $ENV{DEBUG};

        my $cron = Cron::Toolkit->new(expression => $expr);

        my $as_string        = $cron->as_string;
        my $as_unix_string   = $cron->as_unix_string;
        my $as_quartz_string = $cron->as_quartz_string;
        my $desc             = $cron->describe;

        $cron->time_zone($tz)         if $tz;
        $cron->utc_offset($offset_min) if $offset_min && !$tz;

        my $actual_offset = $cron->utc_offset // 0;
        my $local_base    = $BASE->with_offset_same_local($actual_offset);
        my $base_epoch    = $local_base->epoch;

        my $far_past_epoch   = $FAR_PAST->with_offset_same_local($actual_offset)->epoch;
        my $far_future_epoch = $FAR_FUTURE->with_offset_same_local($actual_offset)->epoch;

        $cron->begin_epoch($far_past_epoch);
        $cron->end_epoch($far_future_epoch);

        my ($match_epoch, $is_match, $next_epoch, $next_n, $prev_epoch) = (undef, 0, undef, [], undef);

=pod
        eval {
            $match_epoch = $cron->next($base_epoch) // $cron->next($far_past_epoch);
            if (defined $match_epoch) {
                $is_match  = $cron->is_match($match_epoch);
                $next_epoch = $cron->next($match_epoch + 1);
                $next_epoch = 1 
                my $third   = defined $next_epoch ? $cron->next($next_epoch + 1) : undef;
                $next_n     = [$match_epoch, $next_epoch, $third];
            }
            $prev_epoch = eval { $cron->previous_n($base_epoch, 1, 20000)->[0] };
        };
=cut

        push @data, {
            category         => "general",
            expr             => $expr,
            as_string        => $as_string,
            as_unix_string   => $as_unix_string,
            as_quartz_string => $as_quartz_string,
            type             => ($expr =~ /^@/) ? "alias" : ((split /\s+/, $expr) == 5 && $expr !~ /\?/) ? "unix" : "quartz",
            tz               => $tz,
            utc_offset       => $actual_offset,
            invalid          => 0,
            desc             => $desc,
            match            => { epoch => $match_epoch, is_match => $is_match },
            schedule         => {
                next_epoch => $next_epoch,
                prev_epoch => $prev_epoch,
                next_n     => $next_n
            }
        };
    } or do {
        my $err = $@;
        $err =~ s/\s+at\s+.*$//s;
        print STDERR "DEBUG: Error for '$expr': $err\n" if $ENV{DEBUG};

        push @data, {
            category     => "parsing",
            expr         => $expr,
            invalid      => 1,
            expect_error => $err
        };
    };
}

# ----------------------------------------------------------------------
# Output JSON
# ----------------------------------------------------------------------
my $json = JSON::MaybeXS->new(utf8 => 1, pretty => 1, canonical => 1);
say $json->encode(\@data);
