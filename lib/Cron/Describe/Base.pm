package Cron::Describe::Base;
# ABSTRACT: Base class for parsing and validating standard and Quartz cron expressions

use strict;
use warnings;
use Time::Moment;
use DateTime::TimeZone;
use Carp qw(croak);

# Constructor (assumed to be called by subclasses)
sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
   
    # Store timezone from constructor
    $self->{timezone} = DateTime::TimeZone->new(name => $args{timezone} || 'UTC');
   
    # Parse cron expression (implemented by subclasses)
    $self->{fields} = $self->_parse_expression($args{expression});
   
    # Initialize LRU cache for calendar data (max 12 months)
    $self->{cache} = {};
    $self->{cache_limit} = 12;
    $self->{cache_keys} = []; # Track order for LRU
    $self->{errors} = [];     # Initialize errors array
   
    return $self;
}

# Abstract method for subclasses to implement
sub _parse_expression {
    croak "Subclasses must implement _parse_expression";
}

# Check if a timestamp matches the cron expression
sub is_match {
    my ($self, $epoch) = @_;
   
    # Clear previous errors
    $self->{errors} = [];
   
    # Convert epoch to Time::Moment in specified timezone
    my $tm;
    eval {
        $tm = Time::Moment->from_epoch($epoch, $self->{timezone});
    };
    if ($@) {
        push @{$self->{errors}}, "Invalid timestamp: $@";
        return 0;
    }
   
    # Extract components
    my $components = {
        second => $tm->second, # Quartz only
        minute => $tm->minute,
        hour => $tm->hour,
        day_of_month => $tm->day_of_month,
        month => $tm->month,
        day_of_week => $tm->day_of_week, # 1=Mon, 7=Sun
        year => $tm->year, # Quartz only
    };
   
    # Check each field against allowed values
    my $fields = $self->{fields};
    my $is_quartz = exists $fields->{second}; # Detect Quartz vs Standard
   
    # Quartz: Handle seconds if present
    if ($is_quartz && !$self->_check_field($components->{second}, $fields->{second})) {
        return 0;
    }
   
    # Check minute, hour, month
    for my $field (qw(minute hour month)) {
        return 0 unless $self->_check_field($components->{$field}, $fields->{$field});
    }
   
    # Handle day-of-month and day-of-week
    my $dom = $fields->{day_of_month};
    my $dow = $fields->{day_of_week};
    my $dom_ok = $self->_check_day_of_month($components, $dom, $tm);
    my $dow_ok = $self->_check_day_of_week($components, $dow, $tm);
   
    # Quartz: If either is '?', only the other applies; otherwise, both must match
    # Standard: Both must match
    my $day_match;
    if ($is_quartz) {
        if ($dom eq '?' && $dow eq '?') {
            push @{$self->{errors}}, "Both day-of-month and day-of-week cannot be '?'";
            return 0;
        }
        $day_match = ($dom eq '?' && $dow_ok) || ($dow eq '?' && $dom_ok) || ($dom_ok && $dow_ok);
    } else {
        $day_match = $dom_ok && $dow_ok;
    }
   
    return 0 unless $day_match;
   
    # Quartz: Check year if specified
    if ($is_quartz && exists $fields->{year} && !$self->_check_field($components->{year}, $fields->{year})) {
        return 0;
    }
   
    return 1;
}

# Check if a value is in the allowed field values (using binary search)
sub _check_field {
    my ($self, $value, $allowed) = @_;
   
    # Handle scalar (e.g., '?') or array of allowed values
    return 1 if ref($allowed) eq 'SCALAR' && $$allowed eq '?';
    return 0 unless ref($allowed) eq 'ARRAY';
   
    # Binary search for efficiency
    my ($left, $right) = (0, @$allowed - 1);
    while ($left <= $right) {
        my $mid = int(($left + $right) / 2);
        return 1 if $allowed->[$mid] == $value;
        if ($allowed->[$mid] < $value) {
            $left = $mid + 1;
        } else {
            $right = $mid - 1;
        }
    }
    return 0;
}

# Handle day-of-month, including Quartz 'L' and 'W'
sub _check_day_of_month {
    my ($self, $components, $dom, $tm) = @_;
   
    if (ref($dom) eq 'SCALAR' && $$dom eq 'L') {
        return $components->{day_of_month} == $tm->length_of_month;
    }
    if (ref($dom) eq 'SCALAR' && $$dom =~ /^(\d+)W$/) {
        my $target_day = $1;
        return $self->_is_nearest_weekday($tm, $target_day);
    }
    return $self->_check_field($components->{day_of_month}, $dom);
}

# Handle day-of-week, including Quartz '#' and '?'
sub _check_day_of_week {
    my ($self, $components, $dow, $tm) = @_;
   
    if (ref($dow) eq 'SCALAR' && $$dow eq '?') {
        return 1;
    }
    if (ref($dow) eq 'SCALAR' && $$dow =~ /^(\d+)#(\d+)$/) {
        my ($target_dow, $nth) = ($1, $2);
        return $self->_is_nth_day_of_week($tm, $target_dow, $nth);
    }
    return $self->_check_field($components->{day_of_week}, $dow);
}

# Check if the timestamp is the nearest weekday to target_day
sub _is_nearest_weekday {
    my ($self, $tm, $target_day) = @_;
   
    my $dom = $tm->day_of_month;
    my $dow = $tm->day_of_week; # 1=Mon, 7=Sun
    my $month = $tm->month;
    my $year = $tm->year;
   
    # Cache key for month-specific data
    my $cache_key = "$year-$month";
    $self->_cache_calendar_data($tm, $cache_key) unless exists $self->{cache}->{$cache_key};
   
    my $weekdays = $self->{cache}->{$cache_key}->{weekdays}->{$target_day};
    return $weekdays && $dom == $weekdays->{day};
}

# Check if the timestamp is the nth occurrence of target_dow in the month
sub _is_nth_day_of_week {
    my ($self, $tm, $target_dow, $nth) = @_;
   
    my $month = $tm->month;
    my $year = $tm->year;
    my $cache_key = "$year-$month";
   
    # Cache nth day-of-week calculations
    $self->_cache_calendar_data($tm, $cache_key) unless exists $self->{cache}->{$cache_key};
   
    my $nth_dow = $self->{cache}->{$cache_key}->{nth_dow}->{$target_dow}->{$nth};
    return $nth_dow && $tm->day_of_month == $nth_dow;
}

# Cache calendar data (days in month, weekdays, nth day-of-week)
sub _cache_calendar_data {
    my ($self, $tm, $cache_key) = @_;
   
    my $year = $tm->year;
    my $month = $tm->month;
   
    # LRU cache management
    if (@{$self->{cache_keys}} >= $self->{cache_limit}) {
        my $old_key = shift @{$self->{cache_keys}};
        delete $self->{cache}->{$old_key};
    }
    push @{$self->{cache_keys}}, $cache_key;
   
    # Compute calendar data
    my $data = {
        days => $tm->length_of_month,
        weekdays => {},
        nth_dow => {},
    };
   
    # Compute nearest weekdays for 'W'
    for my $day (1 .. $data->{days}) {
        my $dt = Time::Moment->new(
            year => $year,
            month => $month,
            day => $day,
            time_zone => $self->{timezone}
        );
        my $dow = $dt->day_of_week;
        if ($dow >= 1 && $dow <= 5) { # Mon-Fri
            $data->{weekdays}->{$day} = { day => $day };
        } else {
            # Find nearest weekday
            my $prev = $dt->minus_days(1);
            my $next = $dt->plus_days(1);
            my $prev_dow = $prev->day_of_week;
            my $next_dow = $next->day_of_week;
            my $target_day = ($prev_dow >= 1 && $prev_dow <= 5) ? $prev->day_of_month :
                            ($next_dow >= 1 && $next_dow <= 5) ? $next->day_of_month : undef;
            $data->{weekdays}->{$day} = { day => $target_day } if $target_day;
        }
    }
   
    # Compute nth day-of-week for '#'
    for my $dow (1 .. 7) {
        $data->{nth_dow}->{$dow} = {};
        my $count = 0;
        for my $day (1 .. $data->{days}) {
            my $dt = Time::Moment->new(
                year => $year,
                month => $month,
                day => $day,
                time_zone => $self->{timezone}
            );
            if ($dt->day_of_week == $dow) {
                $count++;
                $data->{nth_dow}->{$dow}->{$count} = $day;
            }
        }
    }
   
    $self->{cache}->{$cache_key} = $data;
}

# Find next fire time after reference epoch
sub next {
    my ($self, $ref_epoch) = @_;
    $ref_epoch //= time;
    my $tm = Time::Moment->from_epoch($ref_epoch, $self->{timezone});
    $tm = $tm->plus_seconds(1);  # Skip current time
    my $max_seconds = 365 * 86400;  # 1 year limit
    my $end_epoch = $ref_epoch + $max_seconds;

    while ($tm->epoch <= $end_epoch) {
        return $tm->epoch if $self->is_match($tm->epoch);
        $tm = $tm->plus_seconds($self->_resolution_seconds);
    }
    push @{$self->{errors}}, "No next match within 1 year from " . $tm->strftime('%Y-%m-%d %H:%M:%S %Z');
    return undef;
}

# Find previous fire time before reference epoch
sub previous {
    my ($self, $ref_epoch) = @_;
    $ref_epoch //= time;
    my $tm = Time::Moment->from_epoch($ref_epoch, $self->{timezone});
    $tm = $tm->minus_seconds(1);
    my $min_epoch = Time::Moment->new(year => 1970, month => 1, day => 1, time_zone => $self->{timezone})->epoch;

    while ($tm->epoch >= $min_epoch) {
        return $tm->epoch if $self->is_match($tm->epoch);
        $tm = $tm->minus_seconds($self->_resolution_seconds);
    }
    push @{$self->{errors}}, "No previous match back to 1970 from " . $tm->strftime('%Y-%m-%d %H:%M:%S %Z');
    return undef;
}

# Resolution in seconds (1 for Quartz, 60 for Standard)
sub _resolution_seconds {
    my ($self) = @_;
    return exists $self->{fields}->{second} ? 1 : 60;
}

1;
