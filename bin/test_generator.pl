#!/usr/bin/env perl
use strict;
use warnings;
use Cron::Toolkit;
use Time::Moment;
use JSON::MaybeXS;
use feature 'say';

# Common TZs and offsets for randomization
my @common_tzs = (
   'America/New_York',       # -300/-240 DST
   'Europe/London',          # 0/+60 BST
   'Asia/Tokyo',             # +540 JST
   'Australia/Sydney',       # +600/+660 AEDT
   'America/Los_Angeles',    # -480/-420 PDT
   'Europe/Paris',           # +60/+120 CEST
);
my @common_offsets = (
   -300,                     # EST
   0,                        # UTC
   60,                       # CET
   540,                      # JST
   -480,                     # PST
   120,                      # EEST
);

my $BASE       = Time::Moment->new( year => 2025, month => 10, day => 23, hour => 0, minute => 0, second => 0 );    # Local-ish start
my $FAR_FUTURE = Time::Moment->new( year => 2030, month => 12, day => 31 );
my $FAR_PAST   = Time::Moment->new( year => 2000, month => 1,  day => 1 );
my @raw_exprs  = (                                                                                                  # Your list...
   '* * * * *',
   '* * * * * ? *',
   '* * * * 7/2',
   '* * * * MON-FRI',
   '*/10 * * * *',
   '*/15 * * * * ?',
   '0 */60 * * * ? *',
   '0 0 * * * ?',
   '0 0 * */32 * ? *',
   '0 0 */3 * * ? *',
   '0 0 0 * * 1#2 ?',
   '0 0 0 * * 2 ?',
   '0 0 0 * * ? *',
   '0 0 0 * * ? 2023',
   '0 0 0 * * ? 2025',
   '0 0 0 * 11/3 ? *',
   '0 0 0 1 JAN ? *',
   '0 0 0 1,15 * * ?',
   '0 0 0 16W * ? *',
   '0 0 0 29 FEB ? *',
   '0 0 0 L * ? *',
   '0 0 0 L-2 * ? *',
   '0 0 0 LW * ? *',
   '0 0 0 LW 6 ? *',
   '0 0 10-14 * * ?',
   '0 30 14 * * ?',
   '0 30 14 * * ? * *',
   '0 30 14 * * ? 2025',
   '0 30 14 ? * 6',
   '0 30 14 ? * MON *',
   '1-5 * * * *',
   '30 14 * *',
   '30 14 * * *',
   '30 14 * * * MON TUE *',
   '30 14 * * 0',
   '30 14 * * 1-5/2',
   '30 14 * * 5-1',
   '30 14 * * MON',
   '30 14 * * SAT',
   '30 14 * * SUN',
   '30 14 * * mOn,WeD,fRi',
   '30 14 * JAN FOO',
   '30 14 * JaN-MaR *',
   '30 14 * XYZ MON',
   '30 14 * jan Mon',
   '30 14 1-15/5 * *',
   '30 14 1-5 * 1-5',
   '30 14 15 * ?',
   '30 14 5-1 * *',
   '30 14 ? * MON',
   '58/3 * * * * ? *',
   '@bogus',
   '@daily',
   '@hourly',
   '@monthly',
   '@yearly',

);

my @data;
for my $expr (@raw_exprs) {
   eval {
      my $cron = Cron::Toolkit->new( expression => $expr );    # Start neutral

      # Randomly assign TZ or offset (33% UTC, rest varied)
      my $rand   = rand();
      my $tz     = undef;
      my $offset = undef;
      if ( $rand < 0.33 ) {

         # 33%: Pure UTC (tz undef)
         $tz = undef;
      }
      else {
         # 67%: Random TZ or offset
         if ( rand() < 0.5 ) {    # 50/50 TZ vs offset
            $tz = $common_tzs[ int( rand(@common_tzs) ) ];
            $cron->time_zone($tz);    # Sets offset DST-aware
         }
         else {
            $offset = $common_offsets[ int( rand(@common_offsets) ) ];
            $cron->utc_offset($offset);    # Fixed offset
            $tz = undef;
         }
      }

      my $norm = $cron->as_string;
      my $desc = $cron->describe;

      # FIXED: Local-adjusted base (local 2025-10-23 00:00 in UTC epoch)
      my $offset_sec = ( $cron->utc_offset // 0 ) * 60;
      my $local_base = $BASE->with_offset_same_local($offset_sec);
      my $base_epoch = $local_base->epoch;

      # Retries with local-adjusted far bounds
      my $far_past_epoch   = $FAR_PAST->with_offset_same_local($offset_sec)->epoch;
      my $far_future_epoch = $FAR_FUTURE->with_offset_same_local($offset_sec)->epoch;
      $cron->begin_epoch($far_past_epoch);
      $cron->end_epoch($far_future_epoch);

      my $match_epoch = $cron->next($base_epoch);
      if ( !defined $match_epoch ) {
         $match_epoch = $cron->next($far_past_epoch);    # Any future from past
      }

      my $next_epoch;
      my $next_n;
      my $prev_epoch = $cron->previous($base_epoch);
      if ( !defined $prev_epoch ) {
         $prev_epoch = $cron->previous($far_future_epoch);    # Any past from future
      }

      if ( defined $match_epoch ) {
         $next_epoch = $cron->next( $match_epoch + 1 );
         if ( !defined $next_epoch ) {
            $next_epoch = $cron->next_n( $match_epoch + 1, 1 )->[0];
         }
         my $third = defined $next_epoch ? $cron->next( $next_epoch + 1 ) : undef;
         if ( !defined $third ) {
            $third = defined $next_epoch ? $cron->next_n( $next_epoch + 1, 1 )->[0] : undef;
         }
         $next_n = [ $match_epoch, $next_epoch, $third ];
      }
      else {
         $next_epoch = undef;
         $next_n     = [ undef, undef, undef ];
      }

      push @data,
        {
         category   => "general",
         expr       => $expr,
         norm       => $norm,
         type       => ( $expr =~ /^@/ ? "alias" : "quartz" ),
         tz         => $tz,
         utc_offset => $offset,
         invalid    => 0,
         desc       => $desc,
         match      => { epoch => $match_epoch, is_match => !!$match_epoch },
         schedule   => {
            next_epoch => $next_epoch,
            prev_epoch => $prev_epoch,
            next_n     => $next_n
         }
        };
   };
   if ($@) {
      push @data,
        {
         category     => "parsing",
         expr         => $expr,
         invalid      => 1,
         expect_error => $@ =~ s/ at .*$//r
        };
   }
}

# Pretty-print
my $json = JSON::MaybeXS->new( utf8 => 1, pretty => 1, indent => 2, canonical => 1 );
say $json->encode( \@data );
