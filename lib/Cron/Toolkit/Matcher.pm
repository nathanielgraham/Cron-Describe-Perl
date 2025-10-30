package Cron::Toolkit::Matcher;
use strict;
use warnings;
use Time::Moment;
use Cron::Toolkit::Utils qw(%LIMITS @FIELDS);
use List::Util           qw(min max);
use Data::Dumper;

sub new {
   my ( $class, %args ) = @_;
   return bless {%args}, $class;
}

sub _set_date {
   my ($self, $tm, $field_type, $value) = @_;
   return $tm->with_second($value) if $field_type eq 'second';
   return $tm->with_minute($value) if $field_type eq 'minute';
   return $tm->with_hour($value) if $field_type eq 'hour';
   return $tm->with_day_of_month($value) if $field_type eq 'dom';
   return $tm->with_month($value) if $field_type eq 'month';
   return $tm->with_year($value) if $field_type eq 'year';
}

sub _plus_one {
   my ($self, $tm, $field_type) = @_;
   return $tm->plus_seconds(1) if $field_type eq 'second';
   return $tm->plus_minutes(1) if $field_type eq 'minute';
   return $tm->plus_hours(1) if $field_type eq 'hour';
   return $tm->plus_days(1) if $field_type eq 'dom';
   return $tm->plus_months(1) if $field_type eq 'month';
   return $tm->plus_years(1) if $field_type eq 'year';
}

# ===================================================================
# MAIN API: next() and previous()
# ===================================================================

sub next {
   my ( $self, $epoch_seconds ) = @_;
   $epoch_seconds //= time;

   my $clamped = max( $epoch_seconds, $self->{begin_epoch} );

   return undef if $clamped > $self->{end_epoch};

   my $tm = Time::Moment->from_epoch($clamped)->with_offset_same_instant( $self->{utc_offset} );

   my @odometer = grep { $_->{field_type} ne 'dow' }
                  grep { $_->{type} eq 'wildcard' || $_->{type} eq 'unspecified' } 
                  @{ $self->{tree}{children} };
   print "RAW: " . $tm->to_string . "\n";

   # set lower constrained fields to lowval 
   foreach my $node ( @{ $self->{tree}{children} } ) {
      if ( $node->{type} ne 'wildcard' && $node->{type} ne 'unspecified' ) {
         my $lowval = $self->_lowest_matching_value($node, $tm);
         $tm = $self->_set_date($tm, $node->{field_type}, $lowval);
      }
      else {
         if ($clamped > $tm->epoch) {
            $self->_field_value($tm, $node->{field_type});
            $tm = $self->_plus_one($tm, $node->{field_type});
         }
         last;
      }
   }

   print "NORMALIZED: " . $tm->to_string . "\n";

   my @constrained_nodes = grep { $_->{type} ne 'wildcard' && $_->{type} ne 'unspecified' }
                           @{ $self->{tree}{children} };

   # EXAMPLE: 0 * * ? * 2 *

   #print STDERR Dumper(\@odometer);
   my $tm_start = $tm->plus_seconds(1);
   my $low_ft = $odometer[0]->{field_type};
   #my ($min, $max) = @{ $LIMITS{ $low_ft } };
   my ($min, $max) = $self->_get_range($tm, $low_ft);
   $min = $self->_field_value($tm_start, $low_ft) ;
   #print "MIN: $min MAX: $max\n";
   #print STDERR "MIN: $min MAX: $max\n";
   my $max_iter = 1000;

   CANDIDATE:
   for my $i ( 0 .. $max_iter ) {
      #$min = $self->_field_value($tm, $low_ft) if $i == 0;
      for my $n ($min .. $max) {
         #print STDERR "BeforeDATE: " . $tm->to_string . "\n";
         #print STDERR "MIN: $min MAX: $max\n";
         $tm = $self->_set_date($tm, $low_ft, $n);
         #$tm = $self->_plus_one($tm, $low_ft);
         #print STDERR "AfterDATE: " . $tm->to_string . "\n";
         if ($self->_match($tm)) {
            print STDERR "MATCH \n";
            return $tm->epoch;
         }
      } # no match

      # reset low counter to min
      $min = $LIMITS{ $low_ft }->[0];
      $tm = $self->_set_date($tm, $low_ft, $min);

      # flip odometer
      for my $o (1 .. $#odometer) {
         my $ft = $odometer[$o]->{field_type};
         my ($ft_min, $ft_max) = $self->_get_range($tm, $ft); 
         my $ft_val = $self->_field_value($tm, $ft);

         #print STDERR "FT: $ft ftmax: $ft_max ftval: $ft_val\n";

         # if counter = max, reset to min and flip next
         if ($ft_val == $ft_max) {
            $tm = $self->_set_date($tm, $ft, $ft_min);
            #print STDERR "MAX REACHED\n";
            next; 
         }

         # flip: add one to next counter
         else {
            #print STDERR "before inc:  $ft, $ft_val, $ft_min, $ft_max\n";
            #print STDERR "CURRENT: " . $tm->to_string . "\n";
            $ft_val++;
            $tm = $self->_set_date($tm, $ft, $ft_val);
            #print STDERR "NEW: " . $tm->to_string . "\n";
            #print STDERR "after inc:  $ft, $ft_val, $ft_min, $ft_max\n";
            next CANDIDATE;
         }
      }
   }
}

sub _get_range {
   my ($self, $tm, $field_type) = @_;
   my $min = $LIMITS{ $field_type }->[0];
   my $max = $field_type eq 'dom' ? $tm->at_last_day_of_month->day_of_month
           : $field_type eq 'dow' ? $tm->at_last_day_of_week->day_of_week
           : $LIMITS{ $field_type }->[1];
   return ($min, $max);
}

sub previous {
   return undef;
}

sub _lowest_matching_value {
    my ($self, $node, $tm) = @_;
    return undef unless $node && $tm;

    my $field = $node->{field_type};
    my $type = $node->{type};

    # === WILDCARD / UNSPECIFIED: lowest in field range ===
    if ($type eq 'wildcard' || $type eq 'unspecified') {
        my ($min) = @{$LIMITS{$field}};
        return $min;
    }

    # === SINGLE ===
    if ($type eq 'single') {
        return $node->{value};
    }

    # === RANGE ===
    if ($type eq 'range') {
        return $node->{children}[0]{value};  # start of range
    }

    # === LIST ===
    if ($type eq 'list') {
        my @vals = map { $_->{value} } grep { $_->{type} eq 'single' } @{$node->{children}};
        return (sort { $a <=> $b } @vals)[0] if @vals;
        return undef;
    }

    # === STEP ===
    if ($type eq 'step') {
        my $base = $node->{children}[0];
        my $step = $node->{children}[1]{value};
        my ($min, $max) = @{$LIMITS{$field}};
        $max = $tm->length_of_month if $field eq 'dom';

        if ($base->{type} eq 'wildcard') {
            return ($min % $step == 0) ? $min : $min + ($step - ($min % $step));
        }

        my $base_val = $base->{type} eq 'single' ? $base->{value}
                     : $base->{children}[0]{value};

        return $base_val if $base_val >= $min && $base_val <= $max;
        return undef;
    }

    # === LAST (L or L-offset) ===
    if ($type eq 'last') {
        my $last_day = $tm->length_of_month;
        if ($node->{value} eq 'L') {
            return $last_day;
        }
        if ($node->{value} =~ /^L-(\d+)$/) {
            my $offset = $1;
            my $target = $last_day - $offset;
            return $target >= 1 ? $target : undef;
        }
    }

    # === LAST WEEKDAY (LW) ===
    if ($type eq 'lastW') {
        my $last_day = $tm->length_of_month;
        my $candidate = $last_day;
        while ($candidate >= 1) {
            my $test_tm = $tm->with_day_of_month($candidate);
            my $dow = $test_tm->day_of_week % 7;
            return $candidate if $dow >= 1 && $dow <= 5;  # Mon-Fri
            $candidate--;
        }
        return undef;
    }

    # === NTH DAY OF WEEK (e.g., 2#1 → first Monday) ===
    if ($type eq 'nth') {
        my ($target_dow, $nth) = $node->{value} =~ /^(\d+)#(\d+)$/;
        $target_dow = ($target_dow == 7) ? 0 : $target_dow - 1;  # Quartz → TM
        $nth = 0 + $nth;

        my $count = 0;
        my $first_match = undef;
        for my $d (1 .. $tm->length_of_month) {
            my $test_tm = $tm->with_day_of_month($d);
            if (($test_tm->day_of_week % 7) == $target_dow) {
                $count++;
                $first_match = $d if $count == $nth;
            }
        }
        return $first_match;
    }

    # === NEAREST WEEKDAY (e.g., 1W) ===
    if ($type eq 'nearest_weekday') {
        my ($target_dom) = $node->{value} =~ /^(\d+)W$/;
        return undef if $target_dom < 1 || $target_dom > $tm->length_of_month;

        my $target_tm = $tm->with_day_of_month($target_dom);
        my $dow = $target_tm->day_of_week % 7;

        # If target is weekday → return it
        return $target_dom if $dow >= 1 && $dow <= 5;

        # Else: check day before
        my $prev = $target_dom - 1;
        if ($prev >= 1) {
            my $prev_tm = $tm->with_day_of_month($prev);
            return $prev if ($prev_tm->day_of_week % 7) >= 1 && ($prev_tm->day_of_week % 7) <= 5;
        }

        # Then: check day after
        my $next = $target_dom + 1;
        if ($next <= $tm->length_of_month) {
            my $next_tm = $tm->with_day_of_month($next);
            return $next if ($next_tm->day_of_week % 7) >= 1 && ($next_tm->day_of_week % 7) <= 5;
        }

        return undef;
    }

    # === FALLBACK ===
    return undef;
}

sub _lowest_matching_value2 {
   my ( $self, $node ) = @_;
   #my ( $self, $node, $field ) = @_;
   return undef unless $node;

   my $field = $node->{field_type};
   my $type = $node->{type};

   # === WILDCARD / UNSPECIFIED ===
   if ( $type eq 'wildcard' || $type eq 'unspecified' ) {
      my ($min) = @{ $LIMITS{$field} };
      return $min;
   }

   # === SINGLE ===
   if ( $type eq 'single' ) {
      return $node->{value};
   }

   # === RANGE ===
   if ( $type eq 'range' ) {
      return $node->{children}[0]{value};
   }

   # === LIST ===
   if ( $type eq 'list' ) {
      my @vals = map { $_->{value} } grep { $_->{type} eq 'single' } @{ $node->{children} };
      return ( sort { $a <=> $b } @vals )[0] if @vals;
      return undef;
   }

   # === STEP ===
   if ( $type eq 'step' ) {
      my $base = $node->{children}[0];
      my $step = $node->{children}[1]{value};
      my ( $min, $max ) = @{ $LIMITS{$field} };
      $max = 28 if $field eq 'dom';    # Safe for lowest

      if ( $base->{type} eq 'wildcard' ) {
         return ( $min % $step == 0 ) ? $min : $min + ( $step - ( $min % $step ) );
      }

      my $base_val =
          $base->{type} eq 'single'
        ? $base->{value}
        : $base->{children}[0]{value};

      return $base_val if $base_val >= $min && $base_val <= $max;
      return undef;
   }

   # === LAST / LAST-OFFSET ===
   if ( $type eq 'last' ) {
      my $last_day = 28;    # Safe minimum
      if ( $node->{value} eq 'L' ) {
         return $last_day;
      }
      if ( $node->{value} =~ /^L-(\d+)$/ ) {
         my $offset = $1;
         my $target = $last_day - $offset;
         return $target >= 1 ? $target : undef;
      }
   }

   # === LAST WEEKDAY (LW) ===
   if ( $type eq 'lastW' ) {
      my $last_day  = 28;
      my $candidate = $last_day;
      while ( $candidate >= 1 ) {
         my $dow = ( $candidate - 1 ) % 7;               # 1=Mon, 7=Sun → 0=Sun,6=Sat
         $dow = 6 if $dow == 0;
         return $candidate if $dow >= 1 && $dow <= 5;    # Mon-Fri
         $candidate--;
      }
      return undef;
   }

   # === NTH DAY OF WEEK ===
   if ( $type eq 'nth' ) {
      my ( $target_dow, $nth ) = $node->{value} =~ /^(\d+)#(\d+)$/;
      $target_dow = ( $target_dow == 7 ) ? 0 : $target_dow - 1;
      $nth        = 0 + $nth;

      my $count = 0;
      for my $d ( 1 .. 28 ) {
         my $dow = ( $d - 1 ) % 7;
         $dow = 6 if $dow == 0;
         if ( $dow == $target_dow ) {
            $count++;
            return $d if $count == $nth;
         }
      }
      return undef;
   }

   # === NEAREST WEEKDAY ===
   if ( $type eq 'nearest_weekday' ) {
      my ($target_dom) = $node->{value} =~ /^(\d+)W$/;
      return undef if $target_dom < 1 || $target_dom > 28;

      my $dow = ( $target_dom - 1 ) % 7;
      $dow = 6 if $dow == 0;

      return $target_dom if $dow >= 1 && $dow <= 5;

      my $prev = $target_dom - 1;
      return $prev if $prev >= 1;

      my $next = $target_dom + 1;
      return $next if $next <= 28;

      return undef;
   }

   return undef;
}

sub _find_next_or_previous {
   my ( $self, $epoch_seconds, $direction ) = @_;
   my $begin_epoch = $self->{owner}->begin_epoch // 0;
   my $end_epoch   = $self->{owner}->end_epoch;

   my $clamped =
     $direction > 0
     ? max( $epoch_seconds, $begin_epoch )
     : min( $epoch_seconds, $end_epoch // $epoch_seconds );

   return undef if $direction > 0 && defined($end_epoch) && $clamped > $end_epoch;
   return undef if $direction < 0 && $clamped < $begin_epoch;

   my $tm = Time::Moment->from_epoch($clamped)->with_offset_same_instant( $self->{utc_offset} );

   $tm = $direction > 0 ? $tm->plus_seconds(1) : $tm->minus_seconds(1);

   my $iter     = 0;
   my $max_iter = 1_000_000;

   while ( $iter++ < $max_iter ) {
      my $epoch = $tm->epoch;
      return $epoch if $self->match($epoch);

      $tm =
          $direction > 0
        ? $self->_advance_to_next_match($tm)
        : $self->_retreat_to_previous_match($tm);

      last unless $tm;
   }
   return undef;
}

# ===================================================================
# CORE: Advance to next valid time
# ===================================================================

sub _advance_to_next_match {
   my ( $self, $tm ) = @_;
   my @nodes = @{ $self->{tree}{children} };

   my $changed = 0;

   # Try to increment from second → minute → hour → dom → month → dow
   for my $i ( 0 .. 5 ) {
      my $node = $nodes[$i] // {};
      my $current =
          $i == 0 ? $tm->second
        : $i == 1 ? $tm->minute
        : $i == 2 ? $tm->hour
        : $i == 3 ? $tm->day_of_month
        : $i == 4 ? $tm->month
        :           $tm->day_of_week % 7;

      my $next_val = $self->_next_allowed_value( $i, $current, $tm );
      if ( defined $next_val ) {
         $tm      = $self->_set_field_value( $tm, $i, $next_val );
         $changed = 1;
         last;
      }
   }

   # If no field could advance → go to next day
   unless ($changed) {
      $tm      = $tm->plus_days(1)->with_hour(0)->with_minute(0)->with_second(0);
      $changed = 1;
   }

   # Reset lower time fields only if a higher field changed
   if ($changed) {
      $tm = $self->_set_time_to_lowest( $tm, $nodes[0], $nodes[1], $nodes[2] );
   }

   return $tm;
}

sub _retreat_to_previous_match {
   my ( $self, $tm ) = @_;
   my @nodes = @{ $self->{tree}{children} };

   my $changed = 0;

   for my $i ( reverse 0 .. 5 ) {
      my $node = $nodes[$i] // {};
      my $current =
          $i == 0 ? $tm->second
        : $i == 1 ? $tm->minute
        : $i == 2 ? $tm->hour
        : $i == 3 ? $tm->day_of_month
        : $i == 4 ? $tm->month
        :           $tm->day_of_week % 7;

      my $prev_val = $self->_prev_allowed_value( $i, $current, $tm );
      if ( defined $prev_val ) {
         $tm      = $self->_set_field_value_prev( $tm, $i, $prev_val );
         $changed = 1;
         last;
      }
   }

   unless ($changed) {
      $tm      = $tm->minus_days(1)->with_hour(23)->with_minute(59)->with_second(59);
      $changed = 1;
   }

   if ($changed) {
      $tm = $self->_set_time_to_highest( $tm, $nodes[0], $nodes[1], $nodes[2] );
   }

   return $tm;
}

# ===================================================================
# HELPERS
# ===================================================================

sub _set_field_value {
   my ( $self, $tm, $i, $val ) = @_;
   return $tm->with_second($val)       if $i == 0;
   return $tm->with_minute($val)       if $i == 1;
   return $tm->with_hour($val)         if $i == 2;
   return $tm->with_day_of_month($val) if $i == 3;
   return $tm->with_month($val)        if $i == 4;

   # DOW: advance to next matching day
   my $current_dow = $tm->day_of_week % 7;
   my $days        = ( $val - $current_dow + 7 ) % 7;
   $days = 7 if $days == 0 && $val != $current_dow;
   return $tm->plus_days($days)->with_hour(0)->with_minute(0)->with_second(0);
}

sub _set_field_value_prev {
   my ( $self, $tm, $i, $val ) = @_;
   return $tm->with_second($val)       if $i == 0;
   return $tm->with_minute($val)       if $i == 1;
   return $tm->with_hour($val)         if $i == 2;
   return $tm->with_day_of_month($val) if $i == 3;
   return $tm->with_month($val)        if $i == 4;
   my $current_dow = $tm->day_of_week % 7;
   my $days        = ( $current_dow - $val + 7 ) % 7;
   $days = 7 if $days == 0 && $val != $current_dow;
   return $tm->minus_days($days)->with_hour(23)->with_minute(59)->with_second(59);
}

sub _set_time_to_lowest {
   my ( $self, $tm, $sec_node, $min_node, $hour_node ) = @_;
   my $sec  = $self->_lowest_allowed( 0, $tm );
   my $min  = $self->_lowest_allowed( 1, $tm );
   my $hour = $self->_lowest_allowed( 2, $tm );
   $tm = $tm->with_second( $sec // 0 );
   $tm = $tm->with_minute( $min // 0 );
   $tm = $tm->with_hour( $hour  // 0 );
   return $tm;
}

sub _set_time_to_highest {
   my ( $self, $tm, $sec_node, $min_node, $hour_node ) = @_;
   my $sec  = $self->_highest_allowed( 0, $tm );
   my $min  = $self->_highest_allowed( 1, $tm );
   my $hour = $self->_highest_allowed( 2, $tm );
   $tm = $tm->with_second( $sec // 59 );
   $tm = $tm->with_minute( $min // 59 );
   $tm = $tm->with_hour( $hour  // 23 );
   return $tm;
}

# ===================================================================
# ORIGINAL METHODS (UNCHANGED)
# ===================================================================

sub match {
   my ( $self, $epoch_seconds ) = @_;
   return 0 unless defined $epoch_seconds;
   my $tm = Time::Moment->from_epoch($epoch_seconds)->with_offset_same_instant( $self->{utc_offset} );
   return $self->_match($tm);
}

sub _match {
   my ( $self, $tm ) = @_;
   my @nodes = @{ $self->{tree}{children} };
   for my $i ( 0 .. $#FIELDS ) {
      my $node = $nodes[$i] or next;
      next if $node->{type} eq 'wildcard' || $node->{type} eq 'unspecified';
      next if $i == 3 && $nodes[5]{type} ne 'unspecified';
      next if $i == 5 && $nodes[3]{type} ne 'unspecified';
      my $value   = $self->_field_value( $tm, $FIELDS[$i] );
      my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new( value => $value, tm => $tm );
      return 0 unless $node->traverse($visitor);
   }
   return 1;
}

sub _field_value {
   my ( $self, $tm, $type ) = @_;
   return $tm->second              if $type eq 'second';
   return $tm->minute              if $type eq 'minute';
   return $tm->hour                if $type eq 'hour';
   return $tm->day_of_month        if $type eq 'dom';
   return $tm->month               if $type eq 'month';
   return $tm->day_of_week         if $type eq 'dow';
   return $tm->year                if $type eq 'year';
}

sub _time_components {
   my ( $self, $tm ) = @_;
   return ( $tm->second, $tm->minute, $tm->hour, $tm->day_of_month, $tm->month, ( $tm->day_of_week % 7 ), $tm->year, );
}

sub _tm_from_components {
   my ( $self, $c ) = @_;
   eval { Time::Moment->new( year => $c->[6], month => $c->[4], day => $c->[3], hour => $c->[2], minute => $c->[1], second => $c->[0], ); } // undef;
}

sub _next_allowed_value {
   my ( $self, $i, $current, $candidate_tm ) = @_;
   my $node  = $self->{tree}{children}[$i];
   my $field = $FIELDS[$i];
   my ( $min, $max ) = @{ $LIMITS{$field} };
   $max = $candidate_tm->length_of_month if $field eq 'dom';

   for my $v ( $current + 1 .. $max ) {
      my $test_tm = $candidate_tm;
      $test_tm = $test_tm->with_day_of_month($v) if $field eq 'dom';
      my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new( value => $v, tm => $test_tm );
      return $v if $node->traverse($visitor);
   }
   return undef;
}

sub _prev_allowed_value {
   my ( $self, $i, $current, $candidate_tm ) = @_;
   my $node  = $self->{tree}{children}[$i];
   my $field = $FIELDS[$i];
   my ( $min, $max ) = @{ $LIMITS{$field} };
   $max = $candidate_tm->length_of_month if $field eq 'dom';

   for my $v ( reverse $min .. $current - 1 ) {
      my $test_tm = $candidate_tm;
      $test_tm = $test_tm->with_day_of_month($v) if $field eq 'dom';
      my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new( value => $v, tm => $test_tm );
      return $v if $node->traverse($visitor);
   }
   return undef;
}

sub _lowest_allowed {
   my ( $self, $i, $candidate_tm ) = @_;
   my $node  = $self->{tree}{children}[$i];
   my $field = $FIELDS[$i];
   my ( $min, $max ) = @{ $LIMITS{$field} };
   $max = $candidate_tm->length_of_month if $field eq 'dom';

   for my $v ( $min .. $max ) {
      my $test_tm = $candidate_tm;
      $test_tm = $test_tm->with_day_of_month($v) if $field eq 'dom';
      my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new( value => $v, tm => $test_tm );
      return $v if $node->traverse($visitor);
   }
   return undef;
}

sub _highest_allowed {
   my ( $self, $i, $candidate_tm ) = @_;
   my $node  = $self->{tree}{children}[$i];
   my $field = $FIELDS[$i];
   my ( $min, $max ) = @{ $LIMITS{$field} };
   $max = $candidate_tm->length_of_month if $field eq 'dom';

   for my $v ( reverse $min .. $max ) {
      my $test_tm = $candidate_tm;
      $test_tm = $test_tm->with_day_of_month($v) if $field eq 'dom';
      my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new( value => $v, tm => $test_tm );
      return $v if $node->traverse($visitor);
   }
   return undef;
}

1;
