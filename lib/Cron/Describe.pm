package Cron::Describe;

# ABSTRACT: Parse and describe standard and Quartz cron expressions, validating their syntax and generating human-readable descriptions

use strict;
use warnings;
use POSIX 'mktime';
use Cron::Describe::Field;
use Cron::Describe::DayOfMonth;
use Cron::Describe::DayOfWeek;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    my $expr = $args{expression} // die "No expression provided";
    my @raw_fields = split /\s+/, $expr;
    my @field_types = $self->is_quartz ? qw(seconds minute hour dom month dow year)
                                      : qw(minute hour dom month dow);
    die "Invalid field count: " . @raw_fields unless @raw_fields == @field_types || ($self->is_quartz && @raw_fields == 6);

    $self->{fields} = [];
    for my $i (0 .. $#raw_fields) {
        my $type = $field_types[$i];
        my $field_class = $type eq 'dom' ? 'Cron::Describe::DayOfMonth'
                        : $type eq 'dow' ? 'Cron::Describe::DayOfWeek'
                        : 'Cron::Describe::Field';
        my $field_args = { type => $type, value => $raw_fields[$i] };
        # Set bounds
        if ($type eq 'seconds' || $type eq 'minute') {
            $field_args->{min} = 0; $field_args->{max} = 59;
        } elsif ($type eq 'hour') {
            $field_args->{min} = 0; $field_args->{max} = 23;
        } elsif ($type eq 'dom') {
            $field_args->{min} = 1; $field_args->{max} = 31;
        } elsif ($type eq 'month') {
            $field_args->{min} = 1; $field_args->{max} = 12;
        } elsif ($type eq 'dow') {
            $field_args->{min} = 0; $field_args->{max} = 7;
        } elsif ($type eq 'year') {
            $field_args->{min} = 1970; $field_args->{max} = 2199;
        }
        push @{$self->{fields}}, $field_class->new(%$field_args);
    }
    return $self;
}

sub is_quartz { 0 } # Overridden in Quartz.pm

sub is_valid {
    my $self = shift;
    # Syntax and bounds check
    for my $field (@{$self->{fields}}) {
        return 0 unless $field->validate();
    }
    # Heuristic check
    my $heuristic_result = $self->_heuristic_is_valid();
    if (defined $heuristic_result) {
        return $heuristic_result;
    }
    # Fallback to simulation for uncertain cases
    return $self->_can_trigger();
}

sub _heuristic_is_valid {
    my $self = shift;
    # Heuristic 1: Basic Field Bounds (already checked in validate, but reinforce)
    # Heuristic 2: Range and Step Validity (already in parse/validate)

    # Field indices (adjust for Quartz/standard)
    my $month_idx = $self->is_quartz ? 4 : 3;
    my $dom_idx = $self->is_quartz ? 3 : 2;
    my $dow_idx = $self->is_quartz ? 5 : 4;
    my $year_idx = $self->is_quartz ? 6 : -1; # No year in standard

    # Heuristic 3: Month-Specific DOM Validity
    my $month_field = $self->{fields}[$month_idx];
    my $dom_field = $self->{fields}[$dom_idx];
    if ($month_field->{parsed}[0]{type} eq 'single' && $dom_field->{parsed}[0]{type} eq 'single') {
        my $month = $month_field->{parsed}[0]{min};
        my $dom = $dom_field->{parsed}[0]{min};
        my $max_days = $self->_days_in_month($month, 2000); # Use non-leap year for heuristic
        if ($dom > $max_days) {
            return 0;
        }
        if ($month == 2 && $dom == 29) {
            return undef; # Uncertain: leap year fallback
        }
    }

    # Heuristic 4: nth DOW Validity
    my $dow_field = $self->{fields}[$dow_idx];
    if ($dow_field->{parsed}[0]{type} eq 'nth') {
        my $nth = $dow_field->{parsed}[0]{nth};
        if ($nth > 5) {
            return 0;
        }
        # For February, check if nth is possible (heuristic max 4 for February)
        if ($month_field->{parsed}[0]{type} eq 'single' && $month_field->{parsed}[0]{min} == 2 && $nth == 5) {
            return undef; # Uncertain: simulation for leap year and specific DOW
        }
        return 1; # Assume valid for other months
    }

    # Heuristic 5: DOW and DOM Conflicts (Quartz-Specific)
    if ($self->is_quartz) {
        if ($dom_field->{parsed}[0]{type} ne '?' && $dow_field->{parsed}[0]{type} ne '?') {
            return 0; # Both can't be specific in Quartz
        }
    }

    # Heuristic 6: Wildcard Validity
    my $all_wildcard = 1;
    for my $field (@{$self->{fields}}) {
        if ($field->{parsed}[0]{type} ne '*' && $field->{parsed}[0]{type} ne '?') {
            $all_wildcard = 0;
            last;
        }
    }
    if ($all_wildcard) {
        return 1;
    }

    # Heuristic 7: Year Validity
    if ($year_idx != -1 && $self->{fields}[$year_idx]{parsed}[0]{type} eq 'single') {
        my $year = $self->{fields}[$year_idx]{parsed}[0]{min};
        if ($year < (localtime)[5] + 1900) {
            return 0; # Past year is invalid
        }
    }

    # Heuristic 8: Leap Year Handling
    # If February 29, fallback to simulation
    if ($month_field->{parsed}[0]{type} eq 'single' && $month_field->{parsed}[0]{min} == 2 && $dom_field->{parsed}[0]{type} eq 'single' && $dom_field->{parsed}[0]{min} == 29) {
        return undef; # Uncertain
    }

    # If no definitive invalid, assume valid
    return 1;
}

sub describe {
    my $self = shift;
    my @descs = map { $_->to_english() } @{$self->{fields}};
    # Format time fields (seconds, minute, hour) as 0 if * or ?
    my @time_parts;
    my $time_start = $self->is_quartz ? 0 : 0;
    my $time_end = $self->is_quartz ? 2 : 1;
    for my $i ($time_start..$time_end) {
        my $desc = $descs[$i] // 'every ' . $self->{fields}[$i]{type};
        push @time_parts, $desc =~ /^every \w+$/ ? 0 : $desc;
    }
    # Add leading 0 for seconds if standard (no seconds)
    unshift @time_parts, 0 if !$self->is_quartz;
    my $time = join(':', @time_parts);
    # Format date fields (dom, month, dow, year)
    my $date_start = $self->is_quartz ? 3 : 2;
    my @date_parts;
    for my $i ($date_start..$#descs) {
        my $type = $self->{fields}[$i]{type};
        $type = 'day-of-month' if $type eq 'dom';
        $type = 'day-of-week' if $type eq 'dow';
        my $desc = $descs[$i] // 'every ' . $type;
        $desc =~ s/^every dom/every day-of-month/;
        $desc =~ s/^every dow/every day-of-week/;
        push @date_parts, $desc;
    }
    return "at $time on " . join(', ', @date_parts);
}

sub _days_in_month {
    my ($self, $mon, $year) = @_;
    my @days = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    my $d = $days[$mon];
    $d = 29 if $mon == 2 && $year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0);
    return $d;
}

sub _dow_of_date {
    my ($self, $year, $mon, $dom) = @_;
    my $epoch = mktime(0, 0, 0, $dom, $mon - 1, $year - 1900, 0, 0, -1);
    my @lt = localtime($epoch);
    return $lt[6];
}

sub _can_trigger {
    my $self = shift;
    my $start_year = (localtime)[5] + 1900;
    for my $year ($start_year .. $start_year + 10) {
        for my $month (1..12) {
            my $days = $self->_days_in_month($month, $year);
            for my $dom (1..$days) {
                my $dow = $self->_dow_of_date($year, $month, $dom);
                my %time_parts = (
                    seconds => 0,
                    minute => 0,
                    hour => 0,
                    dom => $dom,
                    month => $month,
                    dow => $dow,
                    year => $year,
                );
                my $matches_all = 1;
                for my $field (@{$self->{fields}}) {
                    $matches_all = 0 unless $field->matches(\%time_parts);
                }
                return 1 if $matches_all;
            }
        }
    }
    return 0; # No match found
}

1;
