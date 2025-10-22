# NAME

Cron::Toolkit - Cron parser, describer, and scheduler with full Quartz support

# SYNOPSIS

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

# DESCRIPTION

Cron::Toolkit is a comprehensive Perl module for parsing, describing, and scheduling cron expressions. Originally focused on natural language descriptions, it has evolved into a full toolkit for cron manipulation, including timezone-aware matching, bounded searches, and full Quartz enterprise syntax support (seconds field, L/W/#, steps).

Key features:

- Natural Language: "at 2:30 PM on the third Monday of every month in 2025"
- Timezone Aware: time\_zone or utc\_offset for local time matching/next
- Bounded Searches: begin\_epoch/end\_epoch to limit next/previous to a window
- AST Architecture: Tree-based parsing with dual visitors for description and matching—extensible for custom patterns
- Quartz Compatible: Full support for seconds field, L (last), W (weekday), # (nth DOW), steps/ranges/lists
- Production-Ready: 50+ tests, handles edge cases like leap years, month lengths, DOW normalization

# TREE ARCHITECTURE

Cron::Toolkit uses an Abstract Syntax Tree (AST) for expressions:
\- Parse: TreeParser builds Pattern nodes (Single, Range, Step, List, Last, Nth, NearestWeekday)
\- Describe: Composer + EnglishVisitor generates fused English via templates
\- Match: Matcher + MatchVisitor evaluates against timestamps recursively

This decouples parsing from evaluation, making it easy to extend (e.g., new patterns via subclass + visit clause).

# METHODS

## new

    my $cron = Cron::Toolkit->new(
        expression => "0 30 14 * * ?",
        time_zone => "America/New_York",  # Auto-calculates offset
        utc_offset => -300,  # Minutes from UTC
        begin_epoch => 1640995200,  # Optional: Start bound (default: time)
        end_epoch => 1672531200,  # Optional: End bound (default: undef/unbounded)
    );

Constructor. Requires expression. Optional time\_zone/utc\_offset for local time. Optional begin\_epoch/end\_epoch for bounded searches (clamps next/previous).

    expression: Required cron string (Quartz format)
    time_zone: Auto-calculates offset ("America/New_York")
    utc_offset: Minutes from UTC (-300 = NY, 0 = UTC)
    begin_epoch: Non-negative epoch to start searches from (default: time)
    end_epoch: Non-negative epoch to cap searches at (default: undef, unbounded)

## new\_from\_unix

    my $unix_cron = Cron::Toolkit->new_from_unix(
        expression => "30 14 * * MON"
    );

Unix-specific constructor for 5-field expressions. Auto-converts to Quartz (adds seconds=0, year=\*).

## new\_from\_quartz

    my $quartz_cron = Cron::Toolkit->new_from_quartz(
        expression => "0 30 14 * * MON 2025"
    );

Quartz-specific constructor for 6/7-field expressions. Validates and normalizes.

## describe

    my $english = $cron->describe;
    # "at 2:30 PM on the third Monday of every month"

Returns human-readable English description, with fusions for combos (e.g., DOW + year).

## is\_match

    my $match = $cron->is_match($epoch_seconds); # 1 or 0

Returns true if timestamp matches cron expression in object's timezone.

## next

    my $next_epoch = $cron->next($epoch_seconds);
    my $next_epoch = $cron->next; # Uses begin_epoch or current time

Returns the next matching epoch (Unix timestamp) after the given or current time, clamped to end\_epoch if set.

## next\_n

    my $next_epochs = $cron->next_n($epoch_seconds, $n);
    my $next_epochs = $cron->next_n(undef, $n); # Uses begin_epoch or current time

Returns an arrayref of the next $n matching epochs, clamped to end\_epoch.

## previous

    my $prev_epoch = $cron->previous($epoch_seconds);
    my $prev_epoch = $cron->previous; # Uses current time

Returns the previous matching epoch before the given or current time.

## begin\_epoch (GETTER/SETTER)

    say $cron->begin_epoch; # Current start epoch
    $cron->begin_epoch(1640995200); # Set to 2022-01-01 UTC

Gets/sets start epoch for bounded searches (default: time). Clamps next/previous from this time onward.

## end\_epoch (GETTER/SETTER)

    say $cron->end_epoch; # undef or current end epoch
    $cron->end_epoch(1672531200); # Set to 2023-01-01 UTC
    $cron->end_epoch(undef); # Unbounded

Gets/sets end epoch for bounded searches (default: undef/unbounded). Caps next/previous at this time.

## utc\_offset (GETTER/SETTER)

    say $cron->utc_offset; # -300
    $cron->utc_offset(-480); # Switch to PST

Gets/sets UTC offset in minutes. Validates -1080 to +1080.

# QUARTZ SYNTAX SUPPORTED

- Basic : "0 30 14 \* \* ?"
- Steps : "\*/15", "5/3", "10-20/5"
- Ranges : "1-5", "10-14"
- Lists : "1,15", "MON,WED,FRI"
- Last Day : "L", "L-2", "LW"
- Nth DOW : "1#3" = "3rd Sunday"
- Weekday : "15W" = "nearest weekday to 15th"
- Seconds Field : "0 0 30 14 \* \* ? \*" (7-field)
- Names : JAN-MAR, MON-FRI (normalized)

Unix 5-field auto-converted to Quartz (adds seconds=0, year=\*, DOW normalize).

# EXAMPLES

New York Stock Market Open:
  my $ny\_open = Cron::Toolkit->new(
      expression => "0 30 9.5 \* \* 2-6 ?",
      time\_zone => "America/New\_York"
  );
  say $ny\_open->describe; # "at 9:30 AM every Monday through Friday"

Bounded Monthly Backup:
  my $backup = Cron::Toolkit->new(
      expression => "0 0 2 LW \* ? \*",
      time\_zone => "Europe/London"
  );
  $backup->begin\_epoch(Time::Moment->new(year => 2025, month => 1, day => 1)->epoch);
  $backup->end\_epoch(Time::Moment->new(year => 2025, month => 4, day => 1)->epoch);
  if ($backup->is\_match(time)) {
      system("backup.sh");
  }

Third Monday in 2025:
  my $third\_mon = Cron::Toolkit->new(expression => "0 0 0 \* \* 2#3 ? 2025");
  say $third\_mon->describe; # "at midnight on the third Monday in 2025"

Seconds Field (Quartz ATS):
  my $sec\_cron = Cron::Toolkit->new\_from\_quartz(
      expression => "0 0 30 14 \* \* ? \*"
  );
  say $sec\_cron->describe; # "at 2:30:00 PM every month"

# DEBUGGING

    $ENV{Cron_DEBUG} = 1;
    $cron->utc_offset(-300); # "DEBUG: utc_offset: set to -300"

# AUTHOR

Nathaniel J Graham <ngraham@cpan.org>

# COPYRIGHT & LICENSE

Copyright 2025 Nathaniel J Graham.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0).

