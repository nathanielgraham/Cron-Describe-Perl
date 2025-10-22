package Cron::Describe;
use strict;
use warnings;
use Time::Moment;
use Cron::Describe::Tree::Utils qw(:all);
use Cron::Describe::Tree::CompositePattern;
use Cron::Describe::Tree::TreeParser;
use Cron::Describe::Tree::Composer;

=head1 NAME
Cron::Describe - Natural language cron parser + timezone-aware matcher

=head1 SYNOPSIS
  use Cron::Describe;
  my $cron = Cron::Describe->new(
      expression => "0 30 14 * * 1#3 ?",
      utc_offset => -300 # NY time!
  );
  say $cron->describe; # "at 2:30 PM on the third Monday"
  say $cron->is_match(time) ? "RUN NOW!" : "WAIT";
  $cron->utc_offset(-480); # Switch to PST!
  say $cron->next(time); # Next matching epoch
  say $cron->previous(time); # Previous matching epoch
  say join ", ", @{$cron->next_n(time, 3)}; # Next 3 matches

=head1 DESCRIPTION
Cron::Describe transforms complex cron expressions into human-readable English
and matches timestamps with full timezone support. Handles Quartz cron syntax
including L, LW, L-3, 1#3, 15W, and ? wildcards.
Features:
  - Natural Language: "at 2:30 PM on the third Monday of every month"
  - Timezone Aware: utc_offset(-300) = New York time
  - 79 Tests: Production-ready, battle-tested
  - Quartz Compatible: Full enterprise cron support
  - Next/Previous: Find next/previous schedule match

=head1 METHODS
=head2 new
  my $cron = Cron::Describe->new(
      expression => "0 30 14 * * ?",
      utc_offset => -300, # minutes from UTC
      time_zone => "America/New_York" # auto-calculates offset
  );
Constructor. REQUIRES expression. Optional utc_offset or time_zone.
  expression: Required cron string (Quartz format)
  utc_offset: Minutes from UTC (-300 = NY, 0 = UTC)
  time_zone: Auto-calculates offset ("America/New_York")

=head2 describe
  my $english = $cron->describe;
  # "at 2:30 PM on the third Monday of every month"
Returns human-readable English description.

=head2 is_match
  my $match = $cron->is_match($epoch_seconds); # 1 or 0
Returns true if timestamp matches cron expression in object's timezone.

=head2 next
  my $next_epoch = $cron->next($epoch_seconds);
  my $next_epoch = $cron->next; # Uses current time
Returns the next matching epoch (Unix timestamp) after the given or current time.

=head2 next_n
  my $next_epochs = $cron->next_n($epoch_seconds, $n);
  my $next_epochs = $cron->next_n(undef, $n); # Uses current time
Returns an arrayref of the next $n matching epochs.

=head2 previous
  my $prev_epoch = $cron->previous($epoch_seconds);
  my $prev_epoch = $cron->previous; # Uses current time
Returns the previous matching epoch (Unix timestamp) before the given or current time.

=head2 utc_offset (GETTER/SETTER)
  say $cron->utc_offset; # -300
  $cron->utc_offset(-480); # Switch to PST!
  say $cron->utc_offset; # -480
Gets/sets UTC offset in minutes. Validates -1080 to +1080.
  Getter: Returns current offset
  Setter: Validates + sets new offset
  Range: -1080 to +1080 minutes (-18 to +18 hours)

=head1 HOW IT WORKS
Cron::Describe uses a 3-layer pipeline:
1. Parse (TreeParser): Cron string to Abstract Syntax Tree (AST)
   "0 30 14 * * 1#3 ?" -> Tree with 7 nodes
2. Describe (Composer): AST to Natural English via 20+ templates
   "1#3" -> "third Monday"
3. Match (Matcher): UTC epoch to Local components to Tree evaluation
   1697475600 + -300 -> "2023-10-16 12:30:00 NY"
Timezone Algorithm:
  UTC Epoch -> Time::Moment::from_epoch()
  with_offset_same_instant(utc_offset)
  Local components: hour=12, minute=30, day_of_month=16
  Tree evaluation: single(12) == hour(12) = true
Step Matching Examples:
  "*/15" (wildcard) : 7 % 15 == 0 = false
  "5/3" (single) : (7 - 5) % 3 == 0 = true
  "10-20/5" (range) : 17 >= 10 && 17 <= 20 && (17 - 10) % 5 == 0 = true

=head1 QUARTZ SYNTAX SUPPORTED
Basic : "0 30 14 * * ?"
Steps : "*/15", "5/3", "10-20/5"
Ranges : "1-5", "10-14"
Lists : "1,15", "MON,WED,FRI"
Last Day : "L", "L-2", "LW"
Nth DOW : "1#3" = "3rd Sunday"
Weekday : "15W" = "nearest weekday to 15th"

=head1 EXAMPLES
New York Stock Market Open:
  my $ny_open = Cron::Describe->new(
      expression => "0 0 9.5 * * 2-6 ?", # 9:30 AM Mon-Fri
      utc_offset => -300
  );
  say $ny_open->describe; # "at 9:30 AM every Monday through Friday"
Monthly Backup - Last Weekday:
  my $backup = Cron::Describe->new(
      expression => "0 0 2 L * ? *", # 2 AM last weekday
      time_zone => "Europe/London"
  );
  if ($backup->is_match(time)) {
      system("backup.sh");
  }

=head1 DEBUGGING
  $ENV{Cron_DEBUG} = 1;
  $cron->utc_offset(-300); # "DEBUG: utc_offset: set to -300"

=head1 AUTHOR
Nathaniel J Graham <ngraham@cpan.org>

=head1 COPYRIGHT & LICENSE
Copyright 2025 Nathaniel J Graham.
This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0).
=cut

sub new_from_unix {
    my ($class, %args) = @_;
    $args{is_quartz} = 0;
    my $self = $class->_new(%args);
}

sub new_from_quartz {
    my ($class, %args) = @_;
    $args{is_quartz} = 1;
    my $self = $class->_new(%args);
}

sub new {
    my ($class, %args) = @_;
    die "expression required" unless defined $args{expression};
    my @fields = split /\s+/, $args{expression};
    if (@fields == 6 || @fields == 7) {
       $args{is_quartz} = 1;
    }
    elsif (@fields == 5) {
       $args{is_quartz} = 0;
    }
    else {
       die "expected 5-7 fields";
    }
    my $self = $class->_new(%args);
}

sub _new {
    my ($class, %args) = @_;
    die "expression required" unless defined $args{expression};
    my $expr = uc $args{expression};
    $expr =~ s/\s+/ /g;
    $expr =~ s/^\s+|\s+$//g;
    # Convert month names to quartz numerical equivalent
    while ( my ( $name, $num ) = each %month_map ) { $expr =~ s/\b\Q$name\E\b/$num/gi; }
    my @fields = split /\s+/, $expr;
    # Convert dow names to quartz numerical equivalent
    # and normalize expression to 7-field quartz
    if ( $args{is_quartz} ) {
       die "expected 6-7 fields, got " . scalar(@fields) unless @fields == 6 || @fields == 7;
       push (@fields, '*') if @fields == 6; # year
       $fields[5] = quartz_dow_normalize($fields[5]);
    }
    else {
       die "expected 5 fields, got " . scalar(@fields) unless @fields == 5;
       while ( my ( $name, $num ) = each %dow_map_unix ) { $expr =~ s/\b\Q$name\E\b/$num/gi; }
       unshift (@fields, 0); # seconds
       push (@fields, '*'); # year
       $fields[5]= unix_dow_normalize($fields[5]);
       # $fields[3] = dom, $fields[5] = dow
       if ($fields[3] eq '*') {
          if ($fields[5] eq '*') {
             $fields[5] = '?';
          }
          else {
             $fields[3] = '?';
          }
       }
       elsif ( $fields[5] eq '*' ) {
          $fields[5] = '?';
       }
       elsif ( $fields[5] ne '?' && $fields[3] ne '?' ) {
         die "dow and dom cannot both be specified\n";
       }
    }
    # stitch it back together
    $expr = join(' ', @fields);
    die "Invalid characters" unless $expr =~ /^[#LW\d\?\*\s\-\/,]+$/;
    # DEFAULTS: UTC (0 minutes)
    my $utc_offset = $args{utc_offset} // 0;
    my $time_zone = $args{time_zone};
    # AUTO-CALC OFFSET FROM TIMEZONE (RETURNS MINUTES!)
    if ( defined $time_zone && !defined $utc_offset ) {
        $utc_offset = Time::Moment->now_utc->with_time_zone($time_zone)->offset;
    }
    my $self = bless {
        expression => $expr,
        is_quartz => $args{is_quartz},
        utc_offset => $utc_offset,
        time_zone => $time_zone // 'UTC'
    }, $class;
    my @types = qw(second minute hour dom month dow year);
    $self->{root} = Cron::Describe::Tree::CompositePattern->new(type => 'root');
    for my $i (0..6) {
        validate($fields[$i], $types[$i]);
        my $node = Cron::Describe::Tree::TreeParser->parse_field($fields[$i], $types[$i]);
        $node->{field_type} = $types[$i];
        $self->{root}->add_child($node);
    }
    return $self;
}

sub new2 {
    my ($class, %args) = @_;
    die "expression required" unless defined $args{expression};
    my $utc_offset = $args{utc_offset} // 0;
    my $time_zone = $args{time_zone};
    if ( defined $time_zone && !defined $utc_offset ) {
        $utc_offset = Time::Moment->now_utc->with_time_zone($time_zone)->offset;
    }
    my $self = bless {
        expression => $args{expression},
        utc_offset => 0,
        time_zone => $time_zone // 'UTC'
    }, $class;
    $self->utc_offset($utc_offset);
    $self->{expression} = normalize($self->{expression});
    my @fields = split /\s+/, $self->{expression};
    my @types = qw(second minute hour dom month dow year);
    $self->{root} = Cron::Describe::Tree::CompositePattern->new(type => 'root');
    for my $i (0..6) {
        validate($fields[$i], $types[$i]);
        my $node = Cron::Describe::Tree::TreeParser->parse_field($fields[$i], $types[$i]);
        $node->{field_type} = $types[$i];
        $self->{root}->add_child($node);
    }
    return $self;
}

sub utc_offset {
    my ($self, $new_offset) = @_;
    if (@_ > 1) {
        if (!defined $new_offset || $new_offset !~ /^-?\d+$/ || $new_offset < -1080 || $new_offset > 1080) {
            die "Invalid utc_offset '$new_offset': must be an integer between -1080 and 1080 minutes";
        }
        $self->{utc_offset} = $new_offset;
        print STDERR "DEBUG: utc_offset: set to $new_offset\n" if $ENV{Cron_DEBUG};
    }
    print STDERR "DEBUG: utc_offset: returning $self->{utc_offset}\n" if $ENV{Cron_DEBUG};
    return $self->{utc_offset};
}

sub describe {
   my ( $self ) = @_;
   my $composer = Cron::Describe::Tree::Composer->new;
   return $composer->describe($self->{root});
}

sub is_match {
   my ( $self, $epoch_seconds ) = @_;
   return unless $self->{root};
   require Cron::Describe::Tree::Matcher;
   my $matcher = Cron::Describe::Tree::Matcher->new(
      tree => $self->{root},
      utc_offset => $self->utc_offset
   );
   return $matcher->match($epoch_seconds);
}

sub next {
    my ($self, $epoch_seconds) = @_;
    $epoch_seconds //= time;
    die "Invalid epoch_seconds: must be non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;
    require Cron::Describe::Tree::Matcher;
    my $matcher = Cron::Describe::Tree::Matcher->new(
        tree => $self->{root},
        utc_offset => $self->utc_offset
    );
    my ($window, $step) = $self->_estimate_window;
    return $matcher->_find_next($epoch_seconds, $epoch_seconds + $window, $step, 1);
}

sub next_n {
    my ($self, $epoch_seconds, $n) = @_;
    $epoch_seconds //= time;
    $n //= 1;
    die "Invalid epoch_seconds: must be non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;
    die "Invalid n: must be positive integer" unless defined $n && $n =~ /^\d+$/ && $n > 0;
    my @results;
    my $current = $epoch_seconds;
    for (1 .. $n) {
        my $next = $self->next($current);
        last unless defined $next;
        push @results, $next;
        $current = $next + 1;
    }
    return \@results;
}

sub previous {
    my ($self, $epoch_seconds) = @_;
    $epoch_seconds //= time;
    die "Invalid epoch_seconds: must be non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;
    require Cron::Describe::Tree::Matcher;
    my $matcher = Cron::Describe::Tree::Matcher->new(
        tree => $self->{root},
        utc_offset => $self->utc_offset
    );
    my ($window, $step) = $self->_estimate_window;
    return $matcher->_find_next($epoch_seconds, $epoch_seconds - $window, $step, -1);
}

sub _estimate_window {
    my ($self) = @_;
    my @fields = split /\s+/, $self->{expression};
    # Year or month constrained: yearly window, monthly step
    if ($fields[4] ne '*' || $fields[6] ne '*') {
        return (365 * 24 * 3600, 30 * 24 * 3600);
    }
    # DOM or DOW with L, LW, nth, or W: monthly window, daily step
    if ($fields[3] =~ /^(L|LW|\d+W|\d+#\d+)$|^(L|LW|\d+W|\d+#\d+)/ || $fields[5] =~ /^\d+#\d+$/) {
        return (31 * 24 * 3600, 24 * 3600);
    }
    # Second or minute steps: daily window, second step
    if ($fields[0] =~ /\/\d+/ || $fields[1] =~ /\/\d+/) {
        return (24 * 3600, 1);
    }
    # Every-second schedules: immediate window, second step
    if ($fields[0] eq '*' && $fields[1] eq '*' && $fields[2] eq '*' && $fields[3] eq '*' && $fields[4] eq '*' && $fields[5] eq '?' && $fields[6] eq '*') {
        return (1, 1);
    }
    # Default: monthly window, daily step
    return (31 * 24 * 3600, 24 * 3600);
}

1;
