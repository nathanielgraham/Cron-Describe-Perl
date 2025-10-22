package Cron::Describe::Tree::Matcher;
use strict;
use warnings;
use Time::Moment;
use List::Util qw(any);
use Cron::Describe::Tree::Utils qw(quartz_dow);

sub new {
   my ( $class, %args ) = @_;
   return bless {
      tree => $args{tree},
      utc_offset => $args{utc_offset} // 0,
      _time_cache => {} # Cache for _generate_possible_times
   }, $class;
}

sub match {
   my ( $self, $epoch_seconds ) = @_;
   return 0 unless defined $epoch_seconds;
  
   my $tm_utc = Time::Moment->from_epoch($epoch_seconds);
   my $tm_local = $tm_utc->with_offset_same_instant($self->{utc_offset});
  
   my @fields = @{ $self->{tree}{children} };
   my @field_types = qw(second minute hour dom month dow year);
  
   foreach my $i ( 0 .. 6 ) {
      my $field = $fields[$i] or next;
      next if $field->{type} eq 'wildcard';
      my $value = $self->_field_value($tm_local, $field_types[$i]);
      return 0 unless $self->_matches_field($field, $value, $tm_local, $field_types[$i]);
   }
   return 1;
}

sub _field_value {
   my ( $self, $tm, $type ) = @_;
   return $tm->second if $type eq 'second';
   return $tm->minute if $type eq 'minute';
   return $tm->hour if $type eq 'hour';
   return $tm->day_of_month if $type eq 'dom';
   return $tm->month if $type eq 'month';
   return quartz_dow($tm->day_of_week) if $type eq 'dow';
   return $tm->year if $type eq 'year';
}

sub _matches_field {
   my ( $self, $field, $value, $tm, $field_type ) = @_;
   my $type = $field->{type};
  
   return 1 if $type eq 'wildcard';
   return 1 if $type eq 'unspecified';
  
   if ( $type eq 'single' ) {
      if ($field_type eq 'month' && $field->{value} =~ /^[A-Z]{3}$/) {
         my %month_map = (JAN => 1, FEB => 2, MAR => 3, APR => 4, MAY => 5, JUN => 6,
                          JUL => 7, AUG => 8, SEP => 9, OCT => 10, NOV => 11, DEC => 12);
         return $value == $month_map{$field->{value}};
      }
      return $value == $field->{value};
   }
   if ( $type eq 'range' ) {
      my ($min, $max) = map { $_->{value} } @{$field->{children}};
      return $value >= $min && $value <= $max;
   }
   if ( $type eq 'list' ) {
      return any { $_->{value} == $value } @{$field->{children}};
   }
   if ( $type eq 'step' ) {
      return $self->_matches_step($field->{children}[0], $field->{children}[1]{value}, $value);
   }
   if ( $type eq 'last' ) { return $self->_matches_last($field, $tm); }
   if ( $type eq 'lastW' ) { return $self->_matches_lastw($field, $tm); }
   if ( $type eq 'nth' ) { return $self->_matches_nth($field, $tm); }
   if ( $type eq 'nearest_weekday' ) { return $self->_matches_nearest_weekday($field, $tm); }
  
   return 0;
}

sub _matches_step {
   my ( $self, $base, $step, $value ) = @_;
   if ( $base->{type} eq 'wildcard' ) {
      return $value % $step == 0;
   } elsif ( $base->{type} eq 'single' ) {
      return $value >= $base->{value} && ($value - $base->{value}) % $step == 0;
   } elsif ( $base->{type} eq 'range' ) {
      my ($min, $max) = map { $_->{value} } @{$base->{children}};
      return $value >= $min && $value <= $max && ($value - $min) % $step == 0;
   }
   return 0;
}

sub _matches_last {
   my ( $self, $field, $tm ) = @_;
   my $dom = $tm->day_of_month;
   my $days_in_month = $tm->length_of_month;
  
   if ( $field->{value} eq 'L' ) {
      return $dom == $days_in_month;
   }
   if ( $field->{value} =~ /L-(\d+)/ ) {
      my $offset = $1;
      return $dom == $days_in_month - $offset;
   }
   return 0;
}

sub _matches_lastw {
   my ( $self, $field, $tm ) = @_;
   my $dom = $tm->day_of_month;
   my $days_in_month = $tm->length_of_month;
   my $candidate = $days_in_month;
   while ( $candidate >= 1 ) {
      my $test_tm = $tm->with_day_of_month($candidate);
      my $test_dow = quartz_dow($test_tm->day_of_week);
      if ( $test_dow >= 2 && $test_dow <= 6 ) {
         return $dom == $candidate;
      }
      $candidate--;
   }
   return 0;  # Theoretically impossible (months have weekdays), but safe
}

sub _matches_nth {
   my ( $self, $field, $tm ) = @_;
   my ( $dow, $nth ) = $field->{value} =~ /(\d+)#(\d+)/;
   my $target_dow = $dow;
   my $actual_nth = 0;
   my $current_dom = $tm->day_of_month;
   for ( my $d = 1; $d <= $current_dom; $d++ ) {
      my $test_tm = $tm->with_day_of_month($d);
      if ( quartz_dow($test_tm->day_of_week) == $target_dow ) {
         $actual_nth++;
      }
   }
   my $is_target = ( quartz_dow($tm->day_of_week) == $target_dow );
   return $is_target && $actual_nth == $nth;
}

sub _matches_nearest_weekday {
   my ( $self, $field, $tm ) = @_;
   my ($day) = $field->{value} =~ /(\d+)W/;
   my $dom = $tm->day_of_month;
   my $dow = quartz_dow($tm->day_of_week);
   my $days_in_month = $tm->length_of_month;
  
   return 0 if $day < 1 || $day > $days_in_month;
   
   my $target_tm = $tm->with_day_of_month($day);
   my $target_dow = quartz_dow($target_tm->day_of_week);
   
   if ($target_dow >= 2 && $target_dow <= 6) {
      return $dom == $day;
   }
   
   my $before = $target_tm->minus_days(1);
   my $after = $target_tm->plus_days(1);
   my $before_dow = quartz_dow($before->day_of_week);
   my $after_dow = quartz_dow($after->day_of_week);
   
   if ($before_dow >= 2 && $before_dow <= 6 && $dom == $day - 1) {
      return 1;
   }
   if ($after_dow >= 2 && $after_dow <= 6 && $dom == $day + 1 && $day + 1 <= $days_in_month) {
      return 1;
   }
   return 0;
}

sub _find_next {
    my ($self, $start_epoch, $end_epoch, $step, $direction) = @_;
    
    print STDERR "=== FIND NEXT DEBUG ===\n" if $ENV{Cron_DEBUG};
    print STDERR "Start: $start_epoch, End: $end_epoch, Step: $step, Direction: $direction\n" if $ENV{Cron_DEBUG};
    
    my $tm_start = Time::Moment->from_epoch($start_epoch)->with_offset_same_instant($self->{utc_offset});
    my $tm_end = Time::Moment->from_epoch($end_epoch)->with_offset_same_instant($self->{utc_offset});
    
    print STDERR "TM Start: " . $tm_start->strftime('%Y-%m-%d %H:%M:%S') . " ($tm_start->epoch)\n" if $ENV{Cron_DEBUG};
    print STDERR "TM End: " . $tm_end->strftime('%Y-%m-%d %H:%M:%S') . " ($tm_end->epoch)\n" if $ENV{Cron_DEBUG};
    
    my $current = $direction > 0 ? $tm_start->plus_seconds(1) : $tm_start->minus_days(1)->at_midnight;
    my $end = $direction > 0 ? $tm_end->plus_days(1)->at_midnight : $tm_end->at_midnight;
    my $iterations = 0;
    my $max_iterations = 400;
    
    print STDERR "Search: Current=" . $current->strftime('%Y-%m-%d %H:%M:%S') . ", End=" . $end->strftime('%Y-%m-%d %H:%M:%S') . "\n" if $ENV{Cron_DEBUG};
    
    my $is_second_step = $step == 1;
    
    while ($direction > 0 ? $current->epoch <= $end->epoch : $current->epoch >= $end->epoch) {
        $iterations++;
        if ($iterations > $max_iterations) {
            print STDERR "Max iterations ($max_iterations) reached\n" if $ENV{Cron_DEBUG};
            return undef;
        }
        
        my @possible_times;
        if ($is_second_step) {
            @possible_times = ($current);
        } else {
            my $current_day = $current->at_midnight;
            my $cache_key = $current_day->epoch;
            @possible_times = exists $self->{_time_cache}{$cache_key}
                ? @{$self->{_time_cache}{$cache_key}}
                : do {
                    my @times = $self->_generate_possible_times($current_day);
                    $self->{_time_cache}{$cache_key} = \@times;
                    @times;
                };
            print STDERR "Testing day: " . $current_day->strftime('%Y-%m-%d') . ", Generated " . scalar(@possible_times) . " times\n" if $ENV{Cron_DEBUG};
        }
        
        my @sorted_times = $direction > 0 ? sort { $a->epoch <=> $b->epoch } @possible_times : sort { $b->epoch <=> $a->epoch } @possible_times;
        for my $tm (@sorted_times) {
            if ($self->match($tm->epoch) && ($direction > 0 ? $tm->epoch > $start_epoch : $tm->epoch < $start_epoch)) {
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

sub _generate_possible_times {
    my ($self, $day) = @_;
    my @fields = @{ $self->{tree}{children} };
    
    my @seconds = $self->_expand_field($fields[0], 'second');
    my @minutes = $self->_expand_field($fields[1], 'minute');
    my @hours = $self->_expand_field($fields[2], 'hour');
    
    my @times;
    for my $hour (@hours) {
        for my $minute (@minutes) {
            for my $second (@seconds) {
                push @times, $day->with_hour($hour)->with_minute($minute)->with_second($second);
            }
        }
    }
    
    return @times > 1000 ? @times[0..999] : @times;
}

sub _expand_field {
    my ($self, $field, $field_type) = @_;
    my $type = $field->{type};
    
    my @range = $field_type eq 'hour' ? (0..23) : (0..59);
    return @range if $type eq 'wildcard' || $type eq 'unspecified';
    
    if ($type eq 'single') {
        return ($field->{value});
    } elsif ($type eq 'range') {
        my ($min, $max) = map { $_->{value} } @{$field->{children}};
        return ($min .. $max);
    } elsif ($type eq 'list') {
        return map { $_->{value} } @{$field->{children}};
    } elsif ($type eq 'step') {
        my $base = $field->{children}[0];
        my $step = $field->{children}[1]{value};
        my @base_range = $base->{type} eq 'wildcard' ? @range : $self->_expand_field($base, $field_type);
        return grep { ($_ - $base_range[0]) % $step == 0 } @base_range;
    }
    
    return (0);
}

1;
