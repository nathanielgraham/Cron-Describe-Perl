package Cron::Toolkit;
use strict;
use warnings;
use Time::Moment;
use Cron::Toolkit::Tree::Utils qw(:all);
use Cron::Toolkit::Tree::CompositePattern;
use Cron::Toolkit::Tree::TreeParser;
use Cron::Toolkit::Tree::Composer;
use Exporter qw(import);

our @EXPORT_OK = qw(new new_from_unix new_from_quartz);
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

=head1 NAME

Cron::Toolkit - Cron parser, describer, and scheduler with full Quartz support

=head1 SYNOPSIS

  use Cron::Toolkit;
  use Time::Moment;  # For epoch examples

  # Standard constructor (auto-detects Unix/Quartz)
  my $cron = Cron::Toolkit->new(
      expression => "0 30 14 * * 1#3 ?",
      time_zone => "America/New_York"  # Or utc_offset => -300
  );

  # Unix-specific constructor
  my $unix_cron = Cron::Toolkit->new_from_unix(
      expression => "30 14 * * MON"  # Unix 5-field
  );

  # Quartz-specific constructor
  my $quartz_cron = Cron::Toolkit->new_from_quartz(
      expression => "0 30 14 * * MON 2025"  # Quartz 6/7-field
  );

  $cron->begin_epoch(Time::Moment->new(year => 2025, month => 1, day => 1)->epoch);  # Bound to 2025-01-01
  $cron->end_epoch(Time::Moment->new(year => 2025, month => 12, day => 31)->epoch);  # Bound to 2025-12-31

  say $cron->describe; # "at 2:30 PM on the third Sunday of every month"
  say $cron->is_match(time) ? "RUN NOW!" : "WAIT";

  say $cron->next; # Next matching epoch after begin_epoch or now (within end)
  say $cron->previous; # Previous matching epoch before now
  my $nexts = $cron->next_n(3); # Next 3 matches in range
  say join ", ", map { Time::Moment->from_epoch($_)->strftime('%Y-%m-%d %H:%M:%S') } @$nexts;

=head1 DESCRIPTION

Cron::Toolkit is a comprehensive Perl module for parsing, describing, and scheduling cron expressions. Originally focused on natural language descriptions, it has evolved into a full toolkit for cron manipulation, including timezone-aware matching, bounded searches, and full Quartz enterprise syntax support (seconds field, L/W/#, steps).

Key features:

=over 4

=item *

Natural Language: "at 2:30 PM on the third Monday of every month in 2025"

=item *

Timezone Aware: time_zone or utc_offset for local time matching/next

=item *

Bounded Searches: begin_epoch/end_epoch to limit next/previous to a window

=item *

AST Architecture: Tree-based parsing with dual visitors for description and matching—extensible for custom patterns

=item *

Quartz Compatible: Full support for seconds field, L (last), W (weekday), # (nth DOW), steps/ranges/lists

=item *

Production-Ready: 50+ tests, handles edge cases like leap years, month lengths, DOW normalization

=back

=head1 TREE ARCHITECTURE

Cron::Toolkit uses an Abstract Syntax Tree (AST) for expressions:
- Parse: TreeParser builds Pattern nodes (Single, Range, Step, List, Last, Nth, NearestWeekday)
- Describe: Composer + EnglishVisitor generates fused English via templates
- Match: Matcher + MatchVisitor evaluates against timestamps recursively

This decouples parsing from evaluation, making it easy to extend (e.g., new patterns via subclass + visit clause).

=head1 METHODS

=head2 new

  my $cron = Cron::Toolkit->new(
      expression => "0 30 14 * * ?",
      time_zone => "America/New_York",  # Auto-calculates offset
      utc_offset => -300,  # Minutes from UTC
      begin_epoch => 1640995200,  # Optional: Start bound (default: time)
      end_epoch => 1672531200,  # Optional: End bound (default: undef/unbounded)
  );

Constructor. Requires expression. Optional time_zone/utc_offset for local time. Optional begin_epoch/end_epoch for bounded searches (clamps next/previous).

  expression: Required cron string (Quartz format)
  time_zone: Auto-calculates offset ("America/New_York")
  utc_offset: Minutes from UTC (-300 = NY, 0 = UTC)
  begin_epoch: Non-negative epoch to start searches from (default: time)
  end_epoch: Non-negative epoch to cap searches at (default: undef, unbounded)

=head2 new_from_unix

  my $unix_cron = Cron::Toolkit->new_from_unix(
      expression => "30 14 * * MON"
  );

Unix-specific constructor for 5-field expressions. Auto-converts to Quartz (adds seconds=0, year=*).

=head2 new_from_quartz

  my $quartz_cron = Cron::Toolkit->new_from_quartz(
      expression => "0 30 14 * * MON 2025"
  );

Quartz-specific constructor for 6/7-field expressions. Validates and normalizes.

=head2 describe

  my $english = $cron->describe;
  # "at 2:30 PM on the third Monday of every month"

Returns human-readable English description, with fusions for combos (e.g., DOW + year).

=head2 is_match

  my $match = $cron->is_match($epoch_seconds); # 1 or 0

Returns true if timestamp matches cron expression in object's timezone.

=head2 next

  my $next_epoch = $cron->next($epoch_seconds);
  my $next_epoch = $cron->next; # Uses begin_epoch or current time

Returns the next matching epoch (Unix timestamp) after the given or current time, clamped to end_epoch if set.

=head2 next_n

  my $next_epochs = $cron->next_n($epoch_seconds, $n);
  my $next_epochs = $cron->next_n(undef, $n); # Uses begin_epoch or current time

Returns an arrayref of the next $n matching epochs, clamped to end_epoch.

=head2 previous

  my $prev_epoch = $cron->previous($epoch_seconds);
  my $prev_epoch = $cron->previous; # Uses current time

Returns the previous matching epoch before the given or current time.

=head2 begin_epoch (GETTER/SETTER)

  say $cron->begin_epoch; # Current start epoch
  $cron->begin_epoch(1640995200); # Set to 2022-01-01 UTC

Gets/sets start epoch for bounded searches (default: time). Clamps next/previous from this time onward.

=head2 end_epoch (GETTER/SETTER)

  say $cron->end_epoch; # undef or current end epoch
  $cron->end_epoch(1672531200); # Set to 2023-01-01 UTC
  $cron->end_epoch(undef); # Unbounded

Gets/sets end epoch for bounded searches (default: undef/unbounded). Caps next/previous at this time.

=head2 utc_offset (GETTER/SETTER)

  say $cron->utc_offset; # -300
  $cron->utc_offset(-480); # Switch to PST

Gets/sets UTC offset in minutes. Validates -1080 to +1080.

=head1 QUARTZ SYNTAX SUPPORTED

=over 4

=item *

Basic : "0 30 14 * * ?"

=item *

Steps : "*/15", "5/3", "10-20/5"

=item *

Ranges : "1-5", "10-14"

=item *

Lists : "1,15", "MON,WED,FRI"

=item *

Last Day : "L", "L-2", "LW"

=item *

Nth DOW : "1#3" = "3rd Sunday"

=item *

Weekday : "15W" = "nearest weekday to 15th"

=item *

Seconds Field : "0 0 30 14 * * ? *" (7-field)

=item *

Names : JAN-MAR, MON-FRI (normalized)

=back

Unix 5-field auto-converted to Quartz (adds seconds=0, year=*, DOW normalize).

=head1 EXAMPLES

New York Stock Market Open:
  my $ny_open = Cron::Toolkit->new(
      expression => "0 30 9.5 * * 2-6 ?",
      time_zone => "America/New_York"
  );
  say $ny_open->describe; # "at 9:30 AM every Monday through Friday"

Bounded Monthly Backup:
  my $backup = Cron::Toolkit->new(
      expression => "0 0 2 LW * ? *",
      time_zone => "Europe/London"
  );
  $backup->begin_epoch(Time::Moment->new(year => 2025, month => 1, day => 1)->epoch);
  $backup->end_epoch(Time::Moment->new(year => 2025, month => 4, day => 1)->epoch);
  if ($backup->is_match(time)) {
      system("backup.sh");
  }

Third Monday in 2025:
  my $third_mon = Cron::Toolkit->new(expression => "0 0 0 * * 2#3 ? 2025");
  say $third_mon->describe; # "at midnight on the third Monday in 2025"

Seconds Field (Quartz ATS):
  my $sec_cron = Cron::Toolkit->new_from_quartz(
      expression => "0 0 30 14 * * ? *"
  );
  say $sec_cron->describe; # "at 2:30:00 PM every month"

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
        time_zone => $time_zone // 'UTC',
        begin_epoch => $args{begin_epoch},  # undef = use method start_epoch
        end_epoch => $args{end_epoch},  # undef = unbounded
    }, $class;
    my @types = qw(second minute hour dom month dow year);
    $self->{root} = Cron::Toolkit::Tree::CompositePattern->new(type => 'root');
    for my $i (0..6) {
        validate($fields[$i], $types[$i]);
        my $node = Cron::Toolkit::Tree::TreeParser->parse_field($fields[$i], $types[$i]);
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

sub begin_epoch {
    my ($self, $new_begin) = @_;
    if (@_ > 1) {
        die "Invalid begin_epoch '$new_begin': must be a non-negative integer" unless defined $new_begin && $new_begin =~ /^\d+$/ && $new_begin >= 0;
        $self->{begin_epoch} = $new_begin;
    }
    return $self->{begin_epoch};
}

sub end_epoch {
    my ($self, $new_end) = @_;
    if (@_ > 1) {
        die "Invalid end_epoch '$new_end': must be undef or a non-negative integer" unless !defined $new_end || ($new_end =~ /^\d+$/ && $new_end >= 0);
        $self->{end_epoch} = $new_end;
    }
    return $self->{end_epoch};
}

sub describe {
   my ( $self ) = @_;
   my $composer = Cron::Toolkit::Tree::Composer->new;
   return $composer->describe($self->{root});
}

sub is_match {
   my ( $self, $epoch_seconds ) = @_;
   return unless $self->{root};
   require Cron::Toolkit::Tree::Matcher;
   my $matcher = Cron::Toolkit::Tree::Matcher->new(
      tree => $self->{root},
      utc_offset => $self->utc_offset,
      owner => $self
   );
   return $matcher->match($epoch_seconds);
}

sub next {
    my ($self, $epoch_seconds) = @_;
    $epoch_seconds //= time;
    die "Invalid epoch_seconds: must be non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;
    require Cron::Toolkit::Tree::Matcher;
    my $matcher = Cron::Toolkit::Tree::Matcher->new(
        tree => $self->{root},
        utc_offset => $self->utc_offset,
        owner => $self
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
    require Cron::Toolkit::Tree::Matcher;
    my $matcher = Cron::Toolkit::Tree::Matcher->new(
        tree => $self->{root},
        utc_offset => $self->utc_offset,
        owner => $self
    );
    my ($window, $step) = $self->_estimate_window;
    return $matcher->_find_next($epoch_seconds, $epoch_seconds - $window, $step, -1);
}

sub _estimate_window {
    my ($self) = @_;
    my @fields = split /\s+/, $self->{expression};
    # Dom constrained or DOW special: 2-month window, daily step (covers cross-month, intra-month)
    if ($fields[3] ne '*' || $fields[5] =~ /^(L|LW|\d+W|\d+#\d+)$/) {
        return (62 * 24 * 3600, 24 * 3600);
    }
    # Year or month constrained (no dom/DOW special): yearly window, monthly step
    if ($fields[4] ne '*' || $fields[6] ne '*') {
        return (365 * 24 * 3600, 30 * 24 * 3600);
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
