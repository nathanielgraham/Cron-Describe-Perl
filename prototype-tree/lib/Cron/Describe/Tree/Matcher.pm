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
      utc_offset => $args{utc_offset} // 0
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
      return 0 unless $self->_matches_field($field, $value, $tm_local);
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
   my ( $self, $field, $value, $tm ) = @_;
   my $type = $field->{type};
   
   return 1 if $type eq 'wildcard';
   return 1 if $type eq 'unspecified';
   
   if ( $type eq 'single' ) { return $value == $field->{value}; }
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
   if ( $type eq 'lastW' ) { return $self->_matches_lastw($tm); }
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
   my ( $self, $tm ) = @_;
   my $dom = $tm->day_of_month;
   my $dow = quartz_dow($tm->day_of_week);
   my $days_in_month = $tm->length_of_month;
   
   return $dom == $days_in_month && $dow >= 2 && $dow <= 6 ||
          $dom == $days_in_month - 1 && $dow >= 2 && $dow <= 6;
}

sub _matches_nth {
   my ( $self, $field, $tm ) = @_;
   my ( $dow, $nth ) = $field->{value} =~ /(\d+)#(\d+)/;
   my $target_dow = $dow;
   my $actual_nth = 0;
   my $days_in_month = $tm->length_of_month;
   
   for ( my $d = 1; $d <= $days_in_month; $d++ ) {
      my $test_tm = $tm->with_day_of_month($d);
      if ( quartz_dow($test_tm->day_of_week) == $target_dow ) {
         $actual_nth++;
         return 1 if $actual_nth == $nth;
      }
   }
   return 0;
}

sub _matches_nearest_weekday {
   my ( $self, $field, $tm ) = @_;
   my ($day) = $field->{value} =~ /(\d+)W/;
   my $dom = $tm->day_of_month;
   my $dow = quartz_dow($tm->day_of_week);
   return abs($dom - $day) <= 1 && $dow >= 2 && $dow <= 6;
}

1;
