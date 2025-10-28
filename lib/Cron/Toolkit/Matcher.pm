package Cron::Toolkit::Matcher;
use strict;
use warnings;
use Time::Moment;
use Cron::Toolkit::Utils qw(:all);
use List::Util qw(any all max min);

sub new {
   my ( $class, %args ) = @_;
   return bless {
      tree => $args{tree},
      utc_offset => $args{utc_offset} // 0,
      owner => $args{owner}, # New: For bounds access
      _time_cache => {},
   }, $class;
}

# Public wrapper: Find next/previous occurrence with clamping and bounds
sub find_next_or_previous {
   my ( $self, $epoch_seconds, $direction ) = @_;  # +1=next, -1=previous
   die "Invalid direction: must be +1 or -1" unless $direction == 1 || $direction == -1;

   # Clamp to bounds
   my $begin_epoch = $self->{owner}->begin_epoch // 0;
   my $end_epoch = $self->{owner}->end_epoch;
   my $clamped_epoch = $direction > 0
       ? max($epoch_seconds, $begin_epoch)
       : min($epoch_seconds, $end_epoch // $epoch_seconds);

   # Early return if already out of bounds
   return undef if defined $end_epoch && $direction > 0 && $clamped_epoch > $end_epoch;
   return undef if defined $begin_epoch && $direction < 0 && $clamped_epoch < $begin_epoch;

   # Estimate window/step (merged AST + semantic)
   my ( $window, $step ) = $self->_estimate_window;

   # Adjust end_epoch for search (direction-aware)
   my $search_end = $direction > 0
       ? ($end_epoch // ($clamped_epoch + $window))
       : ($begin_epoch // ($clamped_epoch - $window));

   # Invoke core search
   my $result = $self->_find_next($clamped_epoch, $search_end, $step, $direction);

   # Final bounds check (post-search)
   return undef if defined $end_epoch && $direction > 0 && $result && $result > $end_epoch;
   return undef if defined $begin_epoch && $direction < 0 && $result && $result < $begin_epoch;

   return $result;
}

# ----------------------------------------------------------------------
# _estimate_window – merged AST + semantic window/step estimation
# ----------------------------------------------------------------------
sub _estimate_window {
   my $self = shift;
   my $root = $self->{tree};
   my @fields = @{ $self->{owner}{fields} };

   # ------------------------------------------------------------------
   # Phase 1 – find the smallest step in the three time fields
   # ------------------------------------------------------------------
   my $min_step      = 60;   # default = 1 minute
   my $has_time_step = 0;

   for my $i (0 .. 2) {                 # second, minute, hour
      my $child = $root->{children}[$i] or next;
      if ( $child->{type} eq 'step' ) {
         my $step = $child->{children}[1]{value} || 1;
         $min_step      = min( $min_step, $step );
         $has_time_step = 1;
      }
      elsif ( $child->{type} =~ /^(single|range|list|wildcard)$/ ) {
         $min_step = 1;               # any concrete value → 1-second granularity
      }
   }

   # ------------------------------------------------------------------
   # Phase 2 – start with a safe default and then tighten it
   # ------------------------------------------------------------------
   my $window = 86400 * 7;               # 1 week – fallback
   my $step   = max( 1, $min_step );

   # ---- 1. DOM / DOW specials (L, LW, W, #) -----------------------
   if ( $root->{children}[3]{type} =~ /^(last|lastW|nearest_weekday|nth)$/ ||
        $root->{children}[5]{type} =~ /^(last|lastW|nth)$/ ) {
      $window = 62 * 24 * 3600;          # 2-month window
      $step   = 24 * 3600;               # daily step
   }

   # ---- 2. Year or month constrained -----------------------------
   elsif ( $root->{children}[4]{type} ne 'wildcard' ||
           $root->{children}[6]{type} ne 'wildcard' ) {
      $window = 365 * 24 * 3600;         # 1-year window
      $step   = 30 * 24 * 3600;          # monthly step
   }

   # ---- 3. Second / minute steps ---------------------------------
   elsif ( $has_time_step ||
           $fields[0] =~ /\/\d+/ ||      # second step
           $fields[1] =~ /\/\d+/ ) {     # minute step
      $window = 24 * 3600;               # 1-day window
      $step   = 1;                       # second granularity
   }

   # ---- 4. “Every-second” schedule -------------------------------
   else {
      my $every_sec = 1;
      for my $i (0,1,2,3,4,6) {
         $every_sec = 0 unless $root->{children}[$i]{type} eq 'wildcard';
      }
      $every_sec &&= $root->{children}[5]{type} eq 'unspecified';
      if ( $every_sec ) {
         $window = 1;
         $step   = 1;
      }
   }

   # ---- 5. Year-step (*/N in the year field) --------------------
   if ( $window == 86400 * 7 && $root->{children}[6]{type} eq 'step' ) {
      $window = 4 * 365 * 24 * 3600;     # 4-year window (covers leap years)
      $step   = 365 * 24 * 3600;         # yearly step
   }

   # ---- 6. Pure time-only (date fields are all wildcard/unspecified) --
   if ( $window == 86400 * 7 ) {
      my $time_only = 1;
      for my $i (3,4,5,6) {
         $time_only = 0 unless $root->{children}[$i]{type} eq 'wildcard' ||
                               $root->{children}[$i]{type} eq 'unspecified';
      }
      if ( $time_only ) {
         $window = 24 * 3600;            # 1-day window
         $step   = $min_step;            # keep the AST-derived granularity
      }
   }

   # ---- 7. Final fallback (monthly) -------------------------------
   if ( $window == 86400 * 7 ) {
      $window = 31 * 24 * 3600;           # 1-month window
      $step   = 24 * 3600;               # daily step
   }

   # ------------------------------------------------------------------
   # Scale the window so it is a multiple of the step (prevents tiny
   # leftover fragments that could cause the search to stop early)
   # ------------------------------------------------------------------
   $window = int( $window / $step ) * $step if $step > 1;

   print STDERR "DEBUG: Window=$window, Step=$step (min_step=$min_step)\n"
      if $ENV{Cron_DEBUG};

   return ( $window, $step );
}

sub match {
   my ( $self, $epoch_seconds ) = @_;
   return 0 unless defined $epoch_seconds;
   my $tm_utc = Time::Moment->from_epoch($epoch_seconds);
   my $tm_local = $tm_utc->with_offset_same_instant( $self->{utc_offset} );
   my @fields = @{ $self->{tree}{children} };
   my @field_types = qw(second minute hour dom month dow year);
   foreach my $i ( 0 .. 6 ) {
      my $field = $fields[$i] or next;
      next if $field->{type} eq 'wildcard';
      my $value = $self->_field_value( $tm_local, $field_types[$i] );
      # Visitor-wired: Traverse for match
      my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new( value => $value, tm => $tm_local );
      return 0 unless $field->traverse($visitor);
   }
   return 1;
}

# Updated _find_next (strict inequality, better prev start, max_iter=10000)
sub _find_next {
   my ( $self, $start_epoch, $end_epoch, $step, $direction ) = @_;
   print STDERR "=== FIND NEXT DEBUG ===\n" if $ENV{Cron_DEBUG};
   print STDERR "Start: $start_epoch, End: $end_epoch, Step: $step, Direction: $direction\n" if $ENV{Cron_DEBUG};
   my $begin_epoch = $self->{owner}{begin_epoch} // $start_epoch;
   my $end_epoch_obj = $self->{owner}{end_epoch};
   my $effective_start = $direction > 0 ? max( $start_epoch, $begin_epoch ) : min( $start_epoch, $begin_epoch );
   my $effective_end = $direction > 0 ? ( $end_epoch_obj // $end_epoch ) : ( $end_epoch_obj // $end_epoch );
   my $tm_start = Time::Moment->from_epoch($effective_start)->with_offset_same_instant( $self->{utc_offset} );
   my $tm_end = defined $effective_end ? Time::Moment->from_epoch($effective_end)->with_offset_same_instant( $self->{utc_offset} ) : undef;
   print STDERR "TM Start: " . $tm_start->strftime('%Y-%m-%d %H:%M:%S') . " ($tm_start->epoch)\n" if $ENV{Cron_DEBUG};
   print STDERR "TM End: " . ( $tm_end ? $tm_end->strftime('%Y-%m-%d %H:%M:%S') : 'unbounded' ) . " ($tm_end->epoch)\n" if $ENV{Cron_DEBUG};

   # FIXED: Better start for prev (minus step, not days)
   my $current = $direction > 0 ? $tm_start->plus_seconds(1) : $tm_start->minus_seconds($step);
   my $search_end = defined $tm_end ? ( $direction > 0 ? $tm_end->plus_days(1)->at_midnight : $tm_end->at_midnight ) : undef;
   my $iterations = 0;
   my $max_iterations = 10000;  # FIXED: Bump from 400
   my $is_second_step = $step == 1;
   print STDERR "Search: Current=" . $current->strftime('%Y-%m-%d %H:%M:%S') . ", Search End=" . ( $search_end ? $search_end->strftime('%Y-%m-%d %H:%M:%S') : 'unbounded' ) . "\n" if $ENV{Cron_DEBUG};

   while (1) {
      $iterations++;
      if ( $iterations > $max_iterations ) {
         print STDERR "Max iterations ($max_iterations) reached\n" if $ENV{Cron_DEBUG};
         return undef;
      }
      if ( defined $search_end && ( $direction > 0 ? $current->epoch > $search_end->epoch : $current->epoch < $search_end->epoch ) ) {
         last;
      }
      my @possible_times;
      if ($is_second_step) {
         @possible_times = ($current);
      } else {
         my $current_day = $current->at_midnight;
         my $cache_key = $current_day->epoch;
         @possible_times = exists $self->{_time_cache}{$cache_key}
           ? @{ $self->{_time_cache}{$cache_key} }
           : do {
               my @times = $self->_generate_possible_times($current_day);
               $self->{_time_cache}{$cache_key} = \@times;
               @times;
             };
         print STDERR "Testing day: " . $current_day->strftime('%Y-%m-%d') . ", Generated " . scalar(@possible_times) . " times\n" if $ENV{Cron_DEBUG};
      }
      my @sorted_times = $direction > 0 ? sort { $a->epoch <=> $b->epoch } @possible_times : sort { $b->epoch <=> $a->epoch } @possible_times;
      for my $tm (@sorted_times) {
         if ( defined $effective_end && ( $direction > 0 ? $tm->epoch > $effective_end : $tm->epoch < $effective_end ) ) {
            next;
         }
         # FIXED: Strict inequality for next/prev (exclude boundary)
         if ( $self->match( $tm->epoch ) && ( $direction > 0 ? $tm->epoch > $effective_start : $tm->epoch < $effective_start ) ) {
            print STDERR "MATCH at " . $tm->strftime('%Y-%m-%d %H:%M:%S') . " (epoch $tm->epoch)\n" if $ENV{Cron_DEBUG};
            return $tm->epoch;
         }
      }
      $current = $direction > 0 ? $current->plus_seconds($step) : $current->minus_seconds($step);
      print STDERR "Next iteration: Current=" . $current->strftime('%Y-%m-%d %H:%M:%S') . "\n" if $ENV{Cron_DEBUG};
   }
   print STDERR "No match found in window\n" if $ENV{Cron_DEBUG};
   return undef;
}

sub _field_value {
   my ( $self, $tm, $type ) = @_;
   return $tm->second if $type eq 'second';
   return $tm->minute if $type eq 'minute';
   return $tm->hour if $type eq 'hour';
   return $tm->day_of_month if $type eq 'dom';
   return $tm->month if $type eq 'month';
   return quartz_dow( $tm->day_of_week ) if $type eq 'dow';
   return $tm->year if $type eq 'year';
}

sub _generate_possible_times {
   my ( $self, $day ) = @_;
   my @fields = @{ $self->{tree}{children} };
   my @seconds = $self->_expand_field( $fields[0], 'second' );
   my @minutes = $self->_expand_field( $fields[1], 'minute' );
   my @hours = $self->_expand_field( $fields[2], 'hour' );
   my @times;
   for my $hour (@hours) {
      for my $minute (@minutes) {
         for my $second (@seconds) {
            push @times, $day->with_hour($hour)->with_minute($minute)->with_second($second);
         }
      }
   }
   return @times > 1000 ? @times[ 0 .. 999 ] : @times;
}

sub _expand_field {
   my ( $self, $field, $field_type ) = @_;
   my $type = $field->{type};
   my @range = $field_type eq 'hour' ? ( 0 .. 23 ) : ( 0 .. 59 );
   return @range if $type eq 'wildcard' || $type eq 'unspecified';
   if ( $type eq 'single' ) {
      return ( $field->{value} );
   }
   elsif ( $type eq 'range' ) {
      my ( $min, $max ) = map { $_->{value} } @{ $field->{children} };
      return ( $min .. $max );
   }
   elsif ( $type eq 'list' ) {
      return map { $_->{value} } @{ $field->{children} };
   }
   elsif ( $type eq 'step' ) {
      my $base = $field->{children}[0];
      my $step = $field->{children}[1]{value};
      my @base_range = $base->{type} eq 'wildcard' ? @range : $self->_expand_field( $base, $field_type );
      return grep { ( $_ - $base_range[0] ) % $step == 0 } @base_range;
   }
   return (0);
}

1;
