package Cron::Describe;
# ABSTRACT: Parse and describe standard and Quartz cron expressions, validating their syntax and generating human-readable descriptions
use strict;
use warnings;
use POSIX 'mktime';
use DateTime::TimeZone;
use DateTime;
use Cron::Describe::Field;
use Cron::Describe::DayOfMonth;
use Cron::Describe::DayOfWeek;
use Time::Moment;

sub max {
    my ($a, $b) = @_;
    return $a if !defined $b;
    return $b if !defined $a;
    return $a > $b ? $a : $b;
}

sub min {
    my ($a, $b) = @_;
    return $a if !defined $b;
    return $b if !defined $a;
    return $a < $b ? $a : $b;
}

sub new {
    my ($class, %args) = @_;
    my $self = bless { debug => $args{debug} // 0 }, $class;
    my $expr = $args{expression};
    unless (defined $expr && length $expr) {
        $self->{errors} = ["No expression provided"];
        $self->{is_valid} = 0;
        print STDERR "DEBUG: No expression provided, setting is_valid=0\n" if $self->{debug};
        return $self;
    }
    my $tz = $args{time_zone} // 'UTC';
    print STDERR "DEBUG: Describe.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n" if $self->{debug};
    print STDERR "DEBUG: Initializing with class='$class', expression='$expr', time_zone='$tz'\n" if $self->{debug};
    # Validate time zone
    eval { DateTime::TimeZone->new(name => $tz) };
    if ($@) {
        warn "Invalid time zone: $tz; defaulting to UTC";
        $tz = 'UTC';
    }
    $self->{time_zone} = $tz;
    # Normalize expression
    $expr = uc $expr;
    $expr =~ s/\s+/ /g;
    $expr =~ s/^\s+|\s+$//g;
    print STDERR "DEBUG: Normalized expression: '$expr'\n" if $self->{debug};
    # Split into fields
    my @raw_fields = split /\s+/, $expr;
    print STDERR "DEBUG: Split into " . @raw_fields . " fields: [" . join(", ", @raw_fields) . "]\n" if $self->{debug};
    # Initialize fields and errors
    $self->{fields} = [];
    $self->{errors} = [];
    $self->{raw_expression} = $expr;
    # Determine expression type based on class
    $self->{expression_type} = $class =~ /Quartz/ ? 'quartz' : 'standard';
    my @field_types = $self->{expression_type} eq 'quartz' ? qw(seconds minute hour dom month dow year)
                                                          : qw(minute hour dom month dow);
    print STDERR "DEBUG: Expression type set to: $self->{expression_type} (based on class '$class'), expected field types: [" . join(", ", @field_types) . "]\n" if $self->{debug};
    # Validate field count
    my $expected_count = $self->{expression_type} eq 'quartz' ? 6 : 5;
    print STDERR "DEBUG: Checking field count, expected: $expected_count, got: " . @raw_fields . "\n" if $self->{debug};
    if (@raw_fields != $expected_count && !($self->{expression_type} eq 'quartz' && @raw_fields == 7)) {
        push @{$self->{errors}}, "Invalid field count for $self->{expression_type}: got " . @raw_fields . ", expected $expected_count (or 7 for quartz)";
        print STDERR "DEBUG: Invalid field count detected, setting is_valid=0 and returning\n" if $self->{debug};
        $self->{is_valid} = 0;
        return $self;
    }
    print STDERR "DEBUG: Field count valid, proceeding to parse fields\n" if $self->{debug};
    # Parse fields
    for my $i (0 .. $#raw_fields) {
        my $type = $field_types[$i];
        print STDERR "DEBUG: Parsing field $i: $type with value '$raw_fields[$i]'\n" if $self->{debug};
        my $field_args = { field_type => $type, raw_value => $raw_fields[$i] };
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
        # Parse field into intermediate format
        my $field_class = $type eq 'dom' ? 'Cron::Describe::DayOfMonth' :
                          $type eq 'dow' ? 'Cron::Describe::DayOfWeek' :
                          'Cron::Describe::Field';
        my $field = $self->_parse_field($raw_fields[$i], $type, $field_args->{min}, $field_args->{max});
        $field = $field_class->new(%$field, parent => $self); # Pass parent object
        print STDERR "DEBUG: Parsed field $type: " . _dump_field($field) . "\n" if $self->{debug};
        push @{$self->{fields}}, $field;
    }
    print STDERR "DEBUG: Finished parsing loop, fields count: " . @{$self->{fields}} . "\n" if $self->{debug};
    $self->{is_valid} = $self->is_valid;
    print STDERR "DEBUG: is_valid returned: $self->{is_valid}\n" if $self->{debug};
    return $self;
}

sub is_match {
    my ($self, $epoch_seconds) = @_;
    print STDERR "DEBUG: Checking is_match for epoch $epoch_seconds\n" if $self->{debug};
    return 0 if @{$self->{errors}};
    my $tm;
    eval {
        # Adjust epoch for timezone
        my $tz = DateTime::TimeZone->new(name => $self->{time_zone} || 'UTC');
        my $dt = DateTime->from_epoch(epoch => $epoch_seconds, time_zone => $tz);
        $tm = Time::Moment->from_epoch($dt->epoch); # Use UTC epoch
    };
    if ($@) {
        warn "Invalid epoch or time zone: $@";
        print STDERR "DEBUG: Error: Invalid epoch or time zone\n" if $self->{debug};
        return 0;
    }
    my %time_parts = (
        seconds => $tm->second,
        minute => $tm->minute,
        hour => $tm->hour,
        dom => $tm->day_of_month,
        month => $tm->month,
        dow => $tm->day_of_week - 1, # 1=Mon -> 0=Mon
        year => $tm->year,
    );
    print STDERR "DEBUG: Using time_zone=$self->{time_zone}, converted epoch to " . join(", ", map { "$_=$time_parts{$_}" } keys %time_parts) . "\n" if $self->{debug};
    for my $field (@{$self->{fields}}) {
        my $type = $field->{field_type};
        my $val = $time_parts{$type};
        my $matches = $field->matches(\%time_parts);
        print STDERR "DEBUG: Field $type value $val matches: $matches\n" if $self->{debug};
        return 0 unless $matches;
    }
    print STDERR "DEBUG: All fields match\n" if $self->{debug};
    return 1;
}

sub describe {
    my ($self) = @_;
    return $self->to_english; # Compatibility with tests
}

sub _parse_field {
    my ($self, $value, $type, $min, $max) = @_;
    my $field = { field_type => $type, min => $min, max => $max, raw_value => $value };
    print STDERR "DEBUG: Parsing field $type with value '$value'\n" if $self->{debug};
    # Handle Quartz-specific tokens first
    if ($self->{expression_type} eq 'quartz') {
        if ($value eq 'LW' && $type eq 'dom') {
            print STDERR "DEBUG: Matched pattern LW for dom\n" if $self->{debug};
            return { field_type => $type, pattern_type => 'last_weekday', min => $min, max => $max, is_special => 1, offset => 0 };
        } elsif ($value =~ /^L(?:-(\d+))?$/ && $type eq 'dom') {
            my $offset = $1 // 0;
            print STDERR "DEBUG: Matched pattern L(-$offset) for $type\n" if $self->{debug};
            if ($offset > 30) {
                push @{$self->{errors}}, "Invalid offset $offset for $type";
                print STDERR "DEBUG: Error: Invalid offset $offset for $type\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
            return { field_type => $type, pattern_type => 'last', min => $min, max => $max, is_special => 1, offset => $offset };
        } elsif ($value =~ /^(\d+)W$/ && $type eq 'dom') {
            my $day = $1;
            print STDERR "DEBUG: Matched pattern ${day}W for dom\n" if $self->{debug};
            if ($day < 1 || $day > 31) {
                push @{$self->{errors}}, "Invalid day $day for $type";
                print STDERR "DEBUG: Error: Invalid day $day for $type\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
            return { field_type => $type, pattern_type => 'nearest_weekday', min => $min, max => $max, is_special => 1, day => $day };
        } elsif ($value =~ /^(\d+)#(\d+)$/ && $type eq 'dow') {
            my ($day, $nth) = ($1, $2);
            print STDERR "DEBUG: Matched pattern ${day}#${nth} for dow\n" if $self->{debug};
            if ($nth < 1 || $nth > 5 || $day < 0 || $day > 7) {
                push @{$self->{errors}}, "Invalid nth $nth or day $day for $type";
                print STDERR "DEBUG: Error: Invalid nth $nth or day $type\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
            return { field_type => $type, pattern_type => 'nth', min => $min, max => $max, is_special => 1, day => $day, nth => $nth };
        } elsif ($value =~ /^(\d+)L$/ && $type eq 'dow') {
            my $day = $1;
            print STDERR "DEBUG: Matched pattern ${day}L for dow\n" if $self->{debug};
            if ($day < 0 || $day > 7) {
                push @{$self->{errors}}, "Invalid day $day for $type";
                print STDERR "DEBUG: Error: Invalid day $day for $type\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
            return { field_type => $type, pattern_type => 'last_of_day', min => $min, max => $max, is_special => 1, day => $day };
        }
    }
    # Handle day/month names and ranges
    if ($type eq 'month' || $type eq 'dow') {
        if ($value =~ /,/) {
            my @names = split /,/, $value;
            print STDERR "DEBUG: Parsing name list for $type: [" . join(", ", @names) . "]\n" if $self->{debug};
            my @sub_patterns;
            for my $name (@names) {
                my $num = $self->_name_to_num($name, $type);
                if (!defined $num) {
                    push @{$self->{errors}}, "Invalid name $name for $type";
                    print STDERR "DEBUG: Error: Invalid name $name for $type\n" if $self->{debug};
                    return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
                }
                push @sub_patterns, {
                    field_type => $type,
                    pattern_type => 'single',
                    value => $num,
                    min_value => $num,
                    max_value => $num,
                    step => 1,
                    min => $min,
                    max => $max
                };
            }
            return { field_type => $type, pattern_type => 'list', min => $min, max => $max, sub_patterns => \@sub_patterns };
        } elsif ($type eq 'month' && $value =~ /^([A-Z]{3})-([A-Z]{3})$/) {
            my ($start, $end) = ($1, $2);
            print STDERR "DEBUG: Matched month range $start-$end for $type\n" if $self->{debug};
            my $start_num = $self->_name_to_num($start, $type);
            my $end_num = $self->_name_to_num($end, $type);
            if (!defined $start_num || !defined $end_num) {
                push @{$self->{errors}}, "Invalid month range $value for $type";
                print STDERR "DEBUG: Error: Invalid month range $value for $type\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
            if ($start_num > $end_num) {
                push @{$self->{errors}}, "Invalid month range: $start_num > $end_num";
                print STDERR "DEBUG: Error: Invalid month range $start_num > $end_num\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
            return { field_type => $type, pattern_type => 'range', min_value => $start_num, max_value => $end_num, step => 1, min => $min, max => $max };
        } else {
            my $num = $self->_name_to_num($value, $type);
            if (defined $num) {
                print STDERR "DEBUG: Mapped name $value to $num for $type\n" if $self->{debug};
                return { field_type => $type, pattern_type => 'single', value => $num, min_value => $num, max_value => $num, step => 1, min => $min, max => $max };
            }
        }
    }
    # Handle standard patterns
    my @parts = split /,/, $value;
    if (@parts > 1) {
        print STDERR "DEBUG: Parsing list for $type: [" . join(", ", @parts) . "]\n" if $self->{debug};
        my @sub_patterns;
        for my $part (@parts) {
            $part =~ s/^\s+|\s+$//g;
            my $sub_field = $self->_parse_single_part($part, $type, $min, $max);
            push @sub_patterns, $sub_field;
            if ($sub_field->{pattern_type} eq 'error') {
                return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
            }
        }
        return { field_type => $type, pattern_type => 'list', min => $min, max => $max, sub_patterns => \@sub_patterns };
    }
    return $self->_parse_single_part($value, $type, $min, $max);
}

sub _parse_single_part {
    my ($self, $part, $type, $min, $max) = @_;
    my $field = { field_type => $type, min => $min, max => $max, raw_value => $part };
    print STDERR "DEBUG: Parsing single part '$part' for $type\n" if $self->{debug};
    if ($part eq '*' || $part eq '?') {
        print STDERR "DEBUG: Matched pattern $part for $type\n" if $self->{debug};
        $field->{pattern_type} = $part eq '*' ? 'wildcard' : 'unspecified';
        return $field;
    } elsif ($part =~ /^(-?\d+)$/) {
        my $value = $1;
        print STDERR "DEBUG: Matched single pattern $value for $type\n" if $self->{debug};
        my $field_data = {
            field_type => $type,
            value => $value,
            min_value => $value,
            max_value => $value,
            step => 1,
            min => $min,
            max => $max
        };
        if ($value < $min || $value > $max) {
            push @{$self->{errors}}, "Out of bounds: $value for $type";
            print STDERR "DEBUG: Error: Out of bounds $value for $type\n" if $self->{debug};
            $field_data->{pattern_type} = 'error';
        } else {
            $field_data->{pattern_type} = 'single';
        }
        return $field_data;
    } elsif ($part =~ /^(\d+)-(\d+)(?:\/(\d+))?$/) {
        my ($min_val, $max_val, $step) = ($1, $2, $3 // 1);
        print STDERR "DEBUG: Matched range pattern $part for $type\n" if $self->{debug};
        if ($min_val < $min || $max_val > $max || $step <= 0) {
            push @{$self->{errors}}, "Out of bounds: $part for $type";
            print STDERR "DEBUG: Bounds check failed: min_value=$min_val, max_value=$max_val, step=$step for $type\n" if $self->{debug};
            return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
        }
        return { field_type => $type, pattern_type => 'range', min_value => $min_val, max_value => $max_val, step => $step, min => $min, max => $max };
    } elsif ($part =~ /^\*\/(\d+)$/) {
        my $step = $1;
        print STDERR "DEBUG: Matched step pattern $part for $type\n" if $self->{debug};
        if ($step <= 0) {
            push @{$self->{errors}}, "Invalid step: $part for $type";
            print STDERR "DEBUG: Error: Invalid step $step for $type\n" if $self->{debug};
            return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
        }
        return { field_type => $type, pattern_type => 'step', start_value => $min, min_value => $min, max_value => $max, step => $step, min => $min, max => $max };
    } elsif ($part =~ /^(\d+)\/(\d+)$/) {
        my ($start, $step) = ($1, $2);
        print STDERR "DEBUG: Matched step pattern $part for $type\n" if $self->{debug};
        if ($start < $min || $start > $max || $step <= 0) {
            push @{$self->{errors}}, "Out of bounds: $part for $type";
            print STDERR "DEBUG: Bounds check failed: start_value=$start, step=$step for $type\n" if $self->{debug};
            return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
        }
        return { field_type => $type, pattern_type => 'step', start_value => $start, min_value => $start, max_value => $max, step => $step, min => $min, max => $max };
    }
    push @{$self->{errors}}, "Invalid format: $part for $type";
    print STDERR "DEBUG: Error: Invalid format $part for $type\n" if $self->{debug};
    return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
}

sub _name_to_num {
    my ($self, $name, $type) = @_;
    print STDERR "DEBUG: Mapping name '$name' for $type\n" if $self->{debug};
    if ($type eq 'month') {
        my %months = (
            JAN=>1, FEB=>2, MAR=>3, APR=>4, MAY=>5, JUN=>6,
            JUL=>7, AUG=>8, SEP=>9, OCT=>10, NOV=>11, DEC=>12
        );
        my $num = $months{$name};
        print STDERR "DEBUG: Month name '$name' mapped to " . ($num // 'undef') . "\n" if $self->{debug};
        return $num if defined $num;
    } elsif ($type eq 'dow') {
        my %dow = (
            SUN=>0, MON=>1, TUE=>2, WED=>3, THU=>4, FRI=>5, SAT=>6,
            SUNDAY=>0, MONDAY=>1, TUESDAY=>2, WEDNESDAY=>3, THURSDAY=>4, FRIDAY=>5, SATURDAY=>6
        );
        my $num = $dow{$name};
        print STDERR "DEBUG: DOW name '$name' mapped to " . ($num // 'undef') . "\n" if $self->{debug};
        return $num if defined $num;
    }
    return undef;
}

sub is_valid {
    my $self = shift;
    print STDERR "DEBUG: Validating expression\n" if $self->{debug};
    # Check for parsing errors
    if (@{$self->{errors}}) {
        print STDERR "DEBUG: Validation failed due to parsing errors: " . join(", ", @{$self->{errors}}) . "\n" if $self->{debug};
        return 0;
    }
    # Heuristic semantic checks
    my $month_idx = $self->is_quartz ? 4 : 3;
    my $dom_idx = $self->is_quartz ? 3 : 2;
    my $dow_idx = $self->is_quartz ? 5 : 4;
    my $year_idx = $self->is_quartz ? 6 : -1;
    # DOM-Month compatibility
    my $month_field = $self->{fields}[$month_idx];
    my $dom_field = $self->{fields}[$dom_idx];
    my $dow_field = $self->{fields}[$dow_idx];
    my @month_values = $month_field->{pattern_type} eq 'single' ? ($month_field->{value})
                     : $month_field->{pattern_type} eq 'list' ? map { $_->{value} } @{$month_field->{sub_patterns}}
                     : $month_field->{pattern_type} eq 'range' ? ($month_field->{min_value} .. $month_field->{max_value})
                     : (1..12);
    my $is_wild_month = $month_field->{pattern_type} eq 'wildcard';
    my $is_wild_dom = $dom_field->{pattern_type} eq 'wildcard';
    my $max_dom = $is_wild_dom ? 31
                : $dom_field->{pattern_type} eq 'single' ? $dom_field->{value}
                : $dom_field->{pattern_type} eq 'range' || $dom_field->{pattern_type} eq 'step' ? $dom_field->{max_value}
                : $dom_field->{pattern_type} eq 'list' ? max(map { $_->{pattern_type} eq 'single' ? $_->{value} : $_->{max_value} } @{$dom_field->{sub_patterns}})
                : $dom_field->{pattern_type} eq 'last' || $dom_field->{pattern_type} eq 'last_weekday' ? 31
                : $dom_field->{pattern_type} eq 'nearest_weekday' ? $dom_field->{day} + 2
                : $dom_field->{pattern_type} eq 'error' ? $dom_field->{value} // 31
                : 31;
    my $is_valid_dom = 1;
    if ($max_dom > 31) {
        $is_valid_dom = 0;
        push @{$self->{errors}}, "Invalid DOM: max DOM $max_dom exceeds possible days";
        print STDERR "DEBUG: Invalid DOM: max DOM $max_dom exceeds possible days\n" if $self->{debug};
    } elsif (!$is_wild_month && !$is_wild_dom && $dom_field->{pattern_type} ne 'last_weekday') {
        my $year = $year_idx != -1 && defined $self->{fields}[$year_idx] && $self->{fields}[$year_idx]->{pattern_type} eq 'single' ? $self->{fields}[$year_idx]->{value} : undef;
        if ($month_field->{pattern_type} eq 'single' && $month_field->{value} == 2 && $dom_field->{pattern_type} eq 'single' && $dom_field->{value} == 29) {
            if (defined $year && !$self->_is_leap_year($year)) {
                $is_valid_dom = 0;
                push @{$self->{errors}}, "29th of February invalid for non-leap year $year";
                print STDERR "DEBUG: Invalid 29th of February for non-leap year $year\n" if $self->{debug};
            } else {
                print STDERR "DEBUG: Allowing 29th of February (year unspecified or leap year possible)\n" if $self->{debug};
            }
        } else {
            my $max_valid_days = max(map { $self->_days_in_month($_, $year) } @month_values);
            if ($max_dom > $max_valid_days) {
                $is_valid_dom = 0;
                push @{$self->{errors}}, "Invalid DOM for months [" . join(",", @month_values) . "]: max DOM $max_dom exceeds $max_valid_days days";
                print STDERR "DEBUG: Invalid DOM for months [" . join(",", @month_values) . "]: max DOM $max_dom exceeds $max_valid_days days\n" if $self->{debug};
            } else {
                print STDERR "DEBUG: DOM $max_dom valid for at least one month [" . join(",", @month_values) . "] with max $max_valid_days days\n" if $self->{debug};
            }
        }
    } else {
        print STDERR "DEBUG: DOM validation passed (wildcard DOM, month, or last_weekday)\n" if $self->{debug};
    }
    if (!$is_valid_dom) {
        return 0;
    }
    # Quartz DOM-DOW conflict
    if ($self->is_quartz) {
        my $dom_pt = $dom_field->{pattern_type} // '';
        my $dow_pt = $dow_field->{pattern_type} // '';
        my $dom_is_trivial = $dom_pt eq 'wildcard' || $dom_pt eq 'unspecified';
        my $dow_is_trivial = $dow_pt eq 'wildcard' || $dow_pt eq 'unspecified';
        if (!$dom_is_trivial && !$dow_is_trivial) {
            push @{$self->{errors}}, "Quartz DOM-DOW conflict: both non-trivial";
            print STDERR "DEBUG: Invalid Quartz DOM-DOW conflict\n" if $self->{debug};
            return 0;
        }
    }
    # Validate n#m patterns
    if ($self->is_quartz && $dow_field->{pattern_type} eq 'nth') {
        my $target_day = $dow_field->{day};
        my $target_nth = $dow_field->{nth};
        my $year = $year_idx != -1 && defined $self->{fields}[$year_idx] && $self->{fields}[$year_idx]->{pattern_type} eq 'single' ? $self->{fields}[$year_idx]->{value} : 2025;
        my $valid = 0;
        foreach my $month (@month_values) {
            my $tm = Time::Moment->new(year => $year, month => $month, day => 1);
            my $days_in_month = $self->_days_in_month($month, $year);
            my $count = 0;
            for my $day (1..$days_in_month) {
                my $current_tm = Time::Moment->new(year => $year, month => $month, day => $day);
                my $dow = $current_tm->day_of_week; # 1=Mon, 7=Sun
                if ($dow == $target_day || ($target_day == 7 && $dow == 7)) { # Handle Quartz day=7 as Sunday
                    $count++;
                }
            }
            if ($count >= $target_nth) {
                $valid = 1;
                last;
            }
        }
        if (!$valid) {
            push @{$self->{errors}}, "Invalid nth occurrence: $target_day#$target_nth not possible in months [" . join(",", @month_values) . "]";
            print STDERR "DEBUG: Invalid nth occurrence: $target_day#$target_nth not possible\n" if $self->{debug};
            return 0;
        }
    }
    # Year constraints
    if ($year_idx != -1 && defined $self->{fields}[$year_idx]) {
        my $year_field = $self->{fields}[$year_idx];
        my $year_max = $year_field->{pattern_type} eq 'single' ? $year_field->{value}
                     : $year_field->{pattern_type} eq 'range' || $year_field->{pattern_type} eq 'step' ? $year_field->{max_value}
                     : $year_field->{pattern_type} eq 'list' ? max(map { $_->{value} } @{$year_field->{sub_patterns}})
                     : $year_field->{pattern_type} eq 'error' ? $year_field->{value}
                     : $year_field->{max};
        my $year_min = $year_field->{pattern_type} eq 'single' ? $year_field->{value}
                     : $year_field->{pattern_type} eq 'range' || $year_field->{pattern_type} eq 'step' ? $year_field->{min_value}
                     : $year_field->{pattern_type} eq 'list' ? min(map { $_->{value} } @{$year_field->{sub_patterns}})
                     : $year_field->{pattern_type} eq 'error' ? $year_field->{value}
                     : $year_field->{min};
        if (!defined $year_max || !defined $year_min || $year_max > $year_field->{max} || $year_min < $year_field->{min}) {
            push @{$self->{errors}}, "Invalid year range: " . (defined $year_min ? $year_min : 'undef') . "-" . (defined $year_max ? $year_max : 'undef') . " (must be $year_field->{min}-$year_field->{max})";
            print STDERR "DEBUG: Invalid year range: " . (defined $year_min ? $year_min : 'undef') . "-" . (defined $year_max ? $year_max : 'undef') . "\n" if $self->{debug};
            return 0;
        }
    } else {
        print STDERR "DEBUG: Skipping year validation (no year field)\n" if $self->{debug};
    }
    # Pattern consistency (e.g., step > 0)
    for my $field (@{$self->{fields}}) {
        if ($field->{pattern_type} eq 'range' || $field->{pattern_type} eq 'step') {
            if ($field->{step} <= 0) {
                push @{$self->{errors}}, "Invalid step 0 for $field->{field_type}";
                print STDERR "DEBUG: Invalid step 0 for $field->{field_type}\n" if $self->{debug};
                return 0;
            }
        }
        if ($field->{pattern_type} eq 'list') {
            for my $sub (@{$field->{sub_patterns}}) {
                if ($sub->{step} <= 0) {
                    push @{$self->{errors}}, "Invalid sub-step 0 for $field->{field_type}";
                    print STDERR "DEBUG: Invalid sub-step 0 for $field->{field_type}\n" if $self->{debug};
                    return 0;
                }
            }
        }
    }
    print STDERR "DEBUG: Validation passed\n" if $self->{debug};
    return 1;
}

sub is_quartz {
    my $self = shift;
    print STDERR "DEBUG: Checking is_quartz: $self->{expression_type}\n" if $self->{debug};
    return $self->{expression_type} eq 'quartz';
}

sub to_english {
    my ($self) = @_;
    print STDERR "DEBUG: Generating to_english\n" if $self->{debug};
    my @descs;
    for my $field (@{$self->{fields}}) {
        my $expand_steps = ($field->{field_type} eq 'seconds' || $field->{field_type} eq 'minute') && $self->is_quartz ? 1 : 0;
        my $desc = $field->to_english(expand_steps => $expand_steps);
        print STDERR "DEBUG: Field $field->{field_type} description: $desc\n" if $self->{debug};
        push @descs, $desc;
    }
    # Format time fields
    my @time_parts;
    my $time_start = $self->is_quartz ? 0 : 0;
    my $time_end = $self->is_quartz ? 2 : 1;
    for my $i ($time_start .. $time_end) {
        my $desc = $descs[$i] // 'every ' . ($self->{fields}[$i]{field_type} // 'unknown');
        if ($desc =~ /^every (seconds|minute|hour)$/) {
            $desc = '00';
        } elsif ($desc =~ /^every \d+ (seconds|minutes|hours) starting at (\d+)/) {
            $desc = $self->is_quartz ? $descs[$i] : sprintf("%02d", $2);
        }
        push @time_parts, $desc;
    }
    my $time;
    if ($self->is_quartz) {
        if ($time_parts[0] =~ /,/ || $time_parts[1] =~ /,/) {
            $time = join(':', @time_parts);
        } else {
            $time = sprintf("%02s:%02s:%02s", @time_parts);
        }
    } else {
        shift @time_parts; # No seconds in standard
        if ($time_parts[0] =~ /,/) {
            $time = $time_parts[0];
        } else {
            $time = sprintf("%02s:%02s", @time_parts);
        }
    }
    # Format date fields
    my $date_start = $self->is_quartz ? 3 : 2;
    my $date_end = $self->is_quartz ? ($self->{fields}[6] ? 6 : 5) : 4; # Include year if present
    my @date_parts;
    my $dom_idx = $self->is_quartz ? 3 : 2;
    my $month_idx = $self->is_quartz ? 4 : 3;
    my $dow_idx = $self->is_quartz ? 5 : 4;
    my $year_idx = $self->is_quartz ? 6 : -1;
    my $dom_field = $self->{fields}[$dom_idx];
    my $dow_field = $self->{fields}[$dow_idx];
    my $month_field = $self->{fields}[$month_idx];
    my $dom_pt = $dom_field->{pattern_type} // '';
    my $dow_pt = $dow_field->{pattern_type} // '';
    my $month_pt = $month_field->{pattern_type} // '';
    my $skip_dom = ($dom_pt eq 'wildcard' || $dom_pt eq 'unspecified') && !($dow_pt eq 'wildcard' || $dow_pt eq 'unspecified');
    my $skip_dow = ($dow_pt eq 'wildcard' || $dow_pt eq 'unspecified') && ($dom_pt eq 'last' || $dom_pt eq 'nearest_weekday' || $dom_pt eq 'last_weekday');
    for my $i ($date_start .. $date_end) {
        next unless defined $self->{fields}[$i]; # Skip if field undefined
        my $type = $self->{fields}[$i]{field_type} // 'unknown';
        my $pattern = $self->{fields}[$i]{pattern_type} // '';
        print STDERR "DEBUG: Processing field $i: type=$type, pattern=$pattern\n" if $self->{debug};
        my $desc = $descs[$i] // 'every ' . $type;
        $desc =~ s/every dom/every day-of-month/;
        $desc =~ s/every dow/every day-of-week/;
        # Prioritize DOW if non-trivial and DOM is wildcard
        if ($i == $dow_idx && $pattern && !($pattern eq 'wildcard' || $pattern eq 'unspecified')) {
            unshift @date_parts, $desc; # Put DOW first
        } elsif ($i == $dom_idx && $skip_dom) {
            print STDERR "DEBUG: Skipping DOM (wildcard with non-trivial DOW)\n" if $self->{debug};
            next; # Skip wildcard DOM
        } elsif ($i == $dow_idx && $skip_dow) {
            print STDERR "DEBUG: Skipping DOW (unspecified with specific DOM)\n" if $self->{debug};
            next; # Skip unspecified DOW when DOM is specific Quartz pattern
        } elsif ($i == $month_idx && $month_pt eq 'wildcard') {
            push @date_parts, $desc; # Month last if wildcard
        } elsif ($i == $year_idx && $self->{fields}[$i]) {
            push @date_parts, $desc; # Year last if present
        } else {
            push @date_parts, $desc;
        }
    }
    my $result = "Runs at $time on " . join(', ', @date_parts);
    print STDERR "DEBUG: Final description: $result\n" if $self->{debug};
    return $result;
}

sub _days_in_month {
    my ($self, $mon, $year) = @_;
    my $tm = Time::Moment->new(year => $year // 2025, month => $mon, day => 1)->plus_months(1)->minus_days(1);
    my $d = $tm->day_of_month;
    print STDERR "DEBUG: Days in month $mon (year=$year): $d\n" if $self->{debug};
    return $d;
}

sub _dow_of_date {
    my ($self, $year, $mon, $dom) = @_;
    my $tz = DateTime::TimeZone->new(name => $self->{time_zone} || 'UTC');
    my $dt = DateTime->new(year => $year, month => $mon, day => $dom, time_zone => $tz);
    my $tm = Time::Moment->from_epoch($dt->epoch);
    return $tm->day_of_week - 1; # Convert 1-7 to 0-6
}

sub _is_leap_year {
    my ($self, $year) = @_;
    return ($year % 4 == 0 && $year % 100 != 0) || ($year % 400 == 0);
}

sub _dump_field {
    my ($field) = @_;
    my @parts = ("type=" . ($field->{pattern_type} // 'unknown'));
    for my $key (qw(value min_value max_value start_value step offset day nth)) {
        next unless exists $field->{$key};
        push @parts, "$key=" . (defined $field->{$key} ? $field->{$key} : 'undef');
    }
    if (exists $field->{sub_patterns}) {
        push @parts, "sub_patterns=[" . join(", ", map { _dump_field($_) } @{$field->{sub_patterns}}) . "]";
    }
    return "{" . join(", ", @parts) . "}";
}

1;
