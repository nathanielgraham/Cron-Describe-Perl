# NAME

Cron::Describe - Natural language cron parser + timezone-aware matcher

# SYNOPSIS

    use Cron::Describe;

    my $cron = Cron::Describe->new(
        expression  => "0 30 14 * * 1#3 ?",
        utc_offset  => -300  # NY time!
    );

    say $cron->describe;           # "at 2:30 PM on the third Monday"
    say $cron->is_match(time) ? "RUN NOW!" : "WAIT";

    $cron->utc_offset(-480);       # Switch to PST!

# DESCRIPTION

Cron::Describe transforms complex cron expressions into human-readable English
and matches timestamps with full timezone support. Handles Quartz cron syntax
including L, LW, L-3, 1#3, 15W, and ? wildcards.

Features:
  - Natural Language: "at 2:30 PM on the third Monday of every month"
  - Timezone Aware: utc\_offset(-300) = New York time
  - 67 Tests: Production-ready, battle-tested
  - Quartz Compatible: Full enterprise cron support

# METHODS

## new

    my $cron = Cron::Describe->new(
        expression   => "0 30 14 * * ?",
        utc_offset   => -300,     # minutes from UTC
        time_zone    => "America/New_York"  # auto-calculates offset
    );

Constructor. REQUIRES expression. Optional utc\_offset or time\_zone.

    expression: Required cron string (Quartz format)
    utc_offset: Minutes from UTC (-300 = NY, 0 = UTC)
    time_zone:  Auto-calculates offset ("America/New_York")

## describe

    my $english = $cron->describe;
    # "at 2:30 PM on the third Monday of every month"

Returns human-readable English description.

## is\_match

    my $match = $cron->is_match($epoch_seconds);  # 1 or 0

Returns true if timestamp matches cron expression in object's timezone.

## utc\_offset (GETTER/SETTER)

    say $cron->utc_offset;           # -300
    $cron->utc_offset(-480);         # Switch to PST!
    say $cron->utc_offset;           # -480

Gets/sets UTC offset in minutes. Validates -1080 to +1080.

    Getter: Returns current offset
    Setter: Validates + sets new offset
    Range: -1080 to +1080 minutes (-18 to +18 hours)

# HOW IT WORKS

Cron::Describe uses a 3-layer pipeline:

1\. Parse (TreeParser): Cron string to Abstract Syntax Tree (AST)
   "0 30 14 \* \* 1#3 ?" -> Tree with 7 nodes

2\. Describe (Composer): AST to Natural English via 20+ templates
   "1#3" -> "third Monday"

3\. Match (Matcher): UTC epoch to Local components to Tree evaluation
   1697475600 + -300 -> "2023-10-16 12:30:00 NY"

Timezone Algorithm:
  UTC Epoch -> Time::Moment::from\_epoch()
  with\_offset\_same\_instant(utc\_offset)
  Local components: hour=12, minute=30, day\_of\_month=16
  Tree evaluation: single(12) == hour(12) = true

Step Matching Examples:
  "\*/15" (wildcard) : 7 % 15 == 0 = false
  "5/3"  (single)   : (7 - 5) % 3 == 0 = true
  "10-20/5" (range) : 17 >= 10 && 17 <= 20 && (17 - 10) % 5 == 0 = true

# QUARTZ SYNTAX SUPPORTED

Basic     : "0 30 14 \* \* ?"
Steps     : "\*/15", "5/3", "10-20/5"
Ranges    : "1-5", "10-14"
Lists     : "1,15", "MON,WED,FRI"
Last Day  : "L", "L-2", "LW"
Nth DOW   : "1#3" = "3rd Sunday"
Weekday   : "15W" = "nearest weekday to 15th"

# EXAMPLES

New York Stock Market Open:
  my $ny\_open = Cron::Describe->new(
      expression => "0 0 9.5 \* \* 2-6 ?",  # 9:30 AM Mon-Fri
      utc\_offset => -300
  );
  say $ny\_open->describe;  # "at 9:30 AM every Monday through Friday"

Monthly Backup - Last Weekday:
  my $backup = Cron::Describe->new(
      expression => "0 0 2 L \* ? \*",  # 2 AM last weekday
      time\_zone  => "Europe/London"
  );
  if ($backup->is\_match(time)) {
      system("backup.sh");
  }

# DEBUGGING

    $ENV{Cron_DEBUG} = 1;
    $cron->utc_offset(-300);  # "DEBUG: utc_offset: set to -300"

# AUTHOR

Nathaniel J Graham <ngraham@cpan.org>

# COPYRIGHT & LICENSE

Copyright 2025 Nathaniel J Graham.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0).
