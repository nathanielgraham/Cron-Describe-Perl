package Cron::Describe;
# ABSTRACT: Parse and describe standard and Quartz cron expressions, validating their syntax and generating human-readable descriptions
use strict;
use warnings;
use POSIX 'mktime';
use DateTime::TimeZone;
use Cron::Describe::Field;
use Cron::Describe::DayOfMonth;
use Cron::Describe::DayOfWeek;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    my $expr = $args{expression} // die "No expression provided";
    my $tz = $args{time_zone} // 'UTC';
    print STDERR "DEBUG: Describe.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n";
    print STDERR "DEBUG: Normalizing expression '$expr' with time_zone='$tz'\n";
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
    print STDERR "DEBUG: Normalized expression: '$expr'\n";
    # Split into fields
    my @raw_fields = split /\s+/, $expr;
    print STDERR "DEBUG: Split into " . @raw_fields . " fields: [" . join(", ", @raw_fields) . "]\n";
    # Determine expression type
    $self->{expression_type} = @raw_fields >= 6 || $expr =~ /\?|\bL\b|\bW\b|\#/ ? 'quartz' : 'standard';
    my @field_types = $self->{expression_type} eq 'quartz' ? qw(seconds minute hour dom month dow year)
                                                          : qw(minute hour dom month dow);
    print STDERR "DEBUG: Expression type: $self->{expression_type}, expected field types: [" . join(", ", @field_types) . "]\n";
    # Validate field count
    my $expected_count = $self->{expression_type} eq 'quartz' ? 6 : 5;
    $self->{errors} = [];
    if (@raw_fields != $expected_count && !($self->{expression_type} eq 'quartz' && @raw_fields == 7)) {
        push @{$self->{errors}}, "Invalid field count: got " . @raw_fields . ", expected $expected_count";
        print STDERR "DEBUG: Error: Invalid field count\n";
        $self->{is_valid} = 0;
        return $self;
    }
    $self->{raw_expression} = $expr;
    $self->{fields} = [];
    for my $i (0 .. $#raw_fields) {
        my $type = $field_types[$i];
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
        $field = $field_class->new(%$field);
        print STDERR "DEBUG: Parsed field $type: " . _dump_field($field) . "\n";
        push @{$self->{fields}}, $field;
    }
    # Initial validity check
    $self->{is_valid} = @{$self->{errors}} ? 0 : 1;
    return $self;
}

sub describe {
    my ($self) = @_;
    return $self->to_english;  # Compatibility with tests
}

sub _parse_field {
    my ($self, $value, $type, $min, $max) = @_;
    my $field = { field_type => $type, min => $min, max => $max, raw_value => $value, is_special => 0 };
    # Handle Quartz-specific tokens
    if ($value =~ /^[LW#]/) {
        $field->{is_special} = 1;
        if ($value eq 'LW' && $type eq 'dom') {
            $field->{pattern_type} = 'last_weekday';
            $field->{offset} = 0;
            return $field;
        } elsif ($value =~ /^L(?:-(\d+))?$/) {
            my $offset = $1 // 0;
            if ($offset > 30 && $type eq 'dom') {
                push @{$self->{errors}}, "Invalid offset $offset for $type";
                print STDERR "DEBUG: Error: Invalid offset $offset for $type\n";
                return { %$field, pattern_type => 'wildcard', value => undef };
            }
            $field->{pattern_type} = 'last';
            $field->{offset} = $offset;
            return $field;
        } elsif ($value =~ /^(\d+)W$/) {
            my $day = $1;
            if ($day < 1 || $day > 31 || $type ne 'dom') {
                push @{$self->{errors}}, "Invalid day $day for $type";
                print STDERR "DEBUG: Error: Invalid day $day for $type\n";
                return { %$field, pattern_type => 'wildcard', value => undef };
            }
            $field->{pattern_type} = 'nearest_weekday';
            $field->{day} = $day;
            return $field;
        } elsif ($value =~ /^(\d+)#(\d+)$/) {
            my ($day, $nth) = ($1, $2);
            if ($nth < 1 || $nth > 5 || $day < 0 || $day > 7 || $type ne 'dow') {
                push @{$self->{errors}}, "Invalid nth $nth or day $day for $type";
                print STDERR "DEBUG: Error: Invalid nth $nth or day $day for $type\n";
                return { %$field, pattern_type => 'wildcard', value => undef };
            }
            $field->{pattern_type} = 'nth';
            $field->{day} = $day;
            $field->{nth} = $nth;
            return $field;
        } elsif ($value =~ /^(\d+)L$/) {
            my $day = $1;
            if ($day < 0 || $day > 7 || $type ne 'dow') {
                push @{$self->{errors}}, "Invalid day $day for $type";
                print STDERR "DEBUG: Error: Invalid day $day for $type\n";
                return { %$field, pattern_type => 'wildcard', value => undef };
            }
            $field->{pattern_type} = 'last_of_day';
            $field->{day} = $day;
            return $field;
        }
    }
    # Handle day/month names
    if ($type eq 'month' || $type eq 'dow') {
        my $num = $self->_name_to_num($value, $type);
        if (defined $num) {
            $field->{pattern_type} = 'single';
            $field->{value} = $num;
            $field->{min_value} = $num;
            $field->{max_value} = $num;
            $field->{step} = 1;
            return $field;
        }
    }
    # Handle standard patterns
    my @parts = split /,/, $value;
    if (@parts > 1) {
        $field->{pattern_type} = 'list';
        $field->{sub_patterns} = [];
        for my $part (@parts) {
            $part =~ s/^\s+|\s+$//g;
            my $sub_field = $self->_parse_single_part($part, $type, $min, $max);
            push @{$field->{sub_patterns}}, $sub_field;
            if ($sub_field->{pattern_type} eq 'error') {
                $field->{pattern_type} = 'wildcard';
                $field->{sub_patterns} = [];
                last;
            }
        }
        return $field;
    }
    return $self->_parse_single_part($value, $type, $min, $max);
}

sub _parse_single_part {
    my ($self, $part, $type, $min, $max) = @_;
    my $field = { field_type => $type, min => $min, max => $max, raw_value => $part };
    if ($part eq '*' || $part eq '?') {
        $field->{pattern_type} = $part eq '*' ? 'wildcard' : 'unspecified';
        $field->{value} = undef;
        return $field;
    } elsif ($part =~ /^(\d+)-(\d+)(?:\/(\d+))?$/) {
        $field->{pattern_type} = 'range';
        $field->{min_value} = $1;
        $field->{max_value} = $2;
        $field->{step} = $3 // 1;
    } elsif ($part =~ /^(\d+)(?:\/(\d+))?$/) {
        $field->{pattern_type} = 'step';
        $field->{start_value} = $1;
        $field->{min_value} = $1;
        $field->{max_value} = $max;
        $field->{step} = $2 // 1;
    } elsif ($part =~ /^\*\/(\d+)$/) {
        $field->{pattern_type} = 'step';
        $field->{start_value} = $min;
        $field->{min_value} = $min;
        $field->{max_value} = $max;
        $field->{step} = $1;
    } else {
        push @{$self->{errors}}, "Invalid format: $part for $type";
        print STDERR "DEBUG: Error: Invalid format $part for $type\n";
        $field->{pattern_type} = 'wildcard';
        $field->{value} = undef;
    }
    # Bounds check
    if ($field->{pattern_type} ne 'wildcard' && $field->{pattern_type} ne 'unspecified') {
        if ($field->{min_value} < $min || $field->{max_value} > $max || $field->{step} <= 0) {
            push @{$self->{errors}}, "Out of bounds: $part for $type";
            print STDERR "DEBUG: Error: Out of bounds $part for $type\n";
            $field->{pattern_type} = 'wildcard';
            $field->{value} = undef;
        }
    }
    return $field;
}

sub _name_to_num {
    my ($self, $name, $type) = @_;
    print STDERR "DEBUG: Mapping name '$name' for $type\n";
    if ($type eq 'month') {
        my %months = (
            JAN=>1, FEB=>2, MAR=>3, APR=>4, MAY=>5, JUN=>6,
            JUL=>7, AUG=>8, SEP=>9, OCT=>10, NOV=>11, DEC=>12
        );
        my $num = $months{$name};
        print STDERR "DEBUG: Month name '$name' mapped to " . ($num // 'undef') . "\n";
        return $num if defined $num;
    } elsif ($type eq 'dow') {
        my %dow = (
            SUN=>0, MON=>1, TUE=>2, WED=>3, THU=>4, FRI=>5, SAT=>6,
            SUNDAY=>0, MONDAY=>1, TUESDAY=>2, WEDNESDAY=>3, THURSDAY=>4, FRIDAY=>5, SATURDAY=>6
        );
        my $num = $dow{$name};
        print STDERR "DEBUG: DOW name '$name' mapped to " . ($num // 'undef') . "\n";
        return $num if defined $num;
    }
    return undef;
}

sub is_valid {
    my $self = shift;
    print STDERR "DEBUG: Validating expression\n";
    return 0 if @{$self->{errors}};
    # Syntax check
    for my $field (@{$self->{fields}}) {
        if ($field->{pattern_type} eq 'error') {
            print STDERR "DEBUG: Validation failed for $field->{field_type}\n";
            return 0;
        }
    }
    # Heuristic checks
    my $month_idx = $self->is_quartz ? 4 : 3;
    my $dom_idx = $self->is_quartz ? 3 : 2;
    my $dow_idx = $self->is_quartz ? 5 : 4;
    my $year_idx = $self->is_quartz ? 6 : -1;
    my $minute_idx = $self->is_quartz ? 1 : 0;
    # Wildcard check
    my $all_wildcard = 1;
    for my $field (@{$self->{fields}}) {
        if ($field->{pattern_type} ne 'wildcard' && $field->{pattern_type} ne 'unspecified') {
            $all_wildcard = 0;
            last;
        }
    }
    if ($all_wildcard) {
        print STDERR "DEBUG: All wildcard pattern, valid\n";
        return 1;
    }
    # Month-specific DOM check
    my $month_field = $self->{fields}[$month_idx];
    my $dom_field = $self->{fields}[$dom_idx];
    my @month_values = $month_field->{pattern_type} eq 'single' ? ($month_field->{value})
                     : $month_field->{pattern_type} eq 'list' ? map { $_->{value} } @{$month_field->{sub_patterns}}
                     : (1..12);
    for my $month (@month_values) {
        my $max_days = $self->_days_in_month($month, 2000);
        print STDERR "DEBUG: Checking month $month with max_days=$max_days\n";
        if ($dom_field->{pattern_type} eq 'single' && $dom_field->{value} > $max_days) {
            print STDERR "DEBUG: Invalid DOM $dom_field->{value} for month $month\n";
            return 0;
        } elsif ($dom_field->{pattern_type} eq 'range' && $dom_field->{max_value} > $max_days) {
            print STDERR "DEBUG: Invalid DOM range $dom_field->{min_value}-$dom_field->{max_value} for month $month\n";
            return 0;
        } elsif ($dom_field->{pattern_type} eq 'last_weekday') {
            # LW is valid, no specific day check needed
        }
    }
    # Quartz DOM-DOW conflict
    if ($self->is_quartz) {
        my $dom_field = $self->{fields}[$dom_idx];
        my $dow_field = $self->{fields}[$dow_idx];
        my $dom_is_wild = ($dom_field->{pattern_type} // '') eq 'wildcard' || ($dom_field->{pattern_type} // '') eq 'unspecified';
        my $dow_is_wild = ($dow_field->{pattern_type} // '') eq 'wildcard' || ($dow_field->{pattern_type} // '') eq 'unspecified';
        my $dom_is_specific = $dom_field->{pattern_type} eq 'single' || $dom_field->{pattern_type} eq 'range' || 
                              $dom_field->{pattern_type} eq 'last' || $dom_field->{pattern_type} eq 'last_weekday' ||
                              $dom_field->{pattern_type} eq 'nearest_weekday';
        my $dow_is_specific = $dow_field->{pattern_type} eq 'single' || $dow_field->{pattern_type} eq 'range' || 
                              $dow_field->{pattern_type} eq 'nth' || $dow_field->{pattern_type} eq 'last_of_day';
        print STDERR "DEBUG: Quartz DOM-DOW check: dom_wild=$dom_is_wild, dow_wild=$dow_is_wild, dom_specific=$dom_is_specific, dow_specific=$dow_is_specific\n";
        if ($dom_is_specific && $dow_is_specific) {
            print STDERR "DEBUG: Invalid Quartz DOM-DOW conflict\n";
            return 0;
        }
    }
    # Year validity
    if ($year_idx != -1) {
        my $year_field = $self->{fields}[$year_idx];
        if ($year_field->{pattern_type} eq 'single' && $year_field->{value} < (localtime)[5] + 1900) {
            print STDERR "DEBUG: Invalid past year $year_field->{value}\n";
            return 0;
        }
    }
    print STDERR "DEBUG: Validation passed\n";
    return 1;
}

sub is_quartz {
    my $self = shift;
    print STDERR "DEBUG: Checking is_quartz: $self->{expression_type}\n";
    return $self->{expression_type} eq 'quartz';
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english\n";
    my @descs;
    for my $field (@{$self->{fields}}) {
        my $desc = $field->to_english;
        print STDERR "DEBUG: Field $field->{field_type} description: $desc\n";
        push @descs, $desc;
    }
    # Format time fields
    my @time_parts;
    my $time_end = $self->is_quartz ? 2 : 1;
    for my $i (0 .. $time_end) {
        my $desc = $descs[$i] // 'every ' . $self->{fields}[$i]{field_type};
        push @time_parts, $desc =~ /^every \w+$/ ? 0 : $desc;
    }
    unshift @time_parts, 0 if !$self->is_quartz;
    my $time = sprintf("%02d:%02d:%02d", @time_parts);
    # Format date fields
    my $date_start = $self->is_quartz ? 3 : 2;
    my @date_parts;
    for my $i ($date_start .. $#descs) {
        my $type = $self->{fields}[$i]{field_type};
        $type = 'day-of-month' if $type eq 'dom';
        $type = 'day-of-week' if $type eq 'dow';
        my $desc = $descs[$i] // 'every ' . $type;
        push @date_parts, $desc;
    }
    my $result = "Runs at $time on " . join(', ', @date_parts);
    print STDERR "DEBUG: Final description: $result\n";
    return $result;
}

sub _field_to_english {
    my ($self, $field) = @_;
    my $type = $field->{field_type};
    my $pattern = $field->{pattern_type};
    if ($pattern eq 'wildcard' || $pattern eq 'unspecified') {
        return "every $type";
    } elsif ($pattern eq 'single') {
        if ($type eq 'dow') {
            my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday');
            return $dow_names{$field->{value}} || $field->{value};
        } elsif ($type eq 'month') {
            my %month_names = (1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April', 5 => 'May', 6 => 'June',
                               7 => 'July', 8 => 'August', 9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December');
            return $month_names{$field->{value}} || $field->{value};
        }
        return sprintf("%02d", $field->{value});
    } elsif ($pattern eq 'range') {
        return sprintf("%02d-%02d", $field->{min_value}, $field->{max_value}) . ($field->{step} > 1 ? " every $field->{step}" : "");
    } elsif ($pattern eq 'step') {
        return "every $field->{step} ${type}s starting at " . sprintf("%02d", $field->{start_value});
    } elsif ($pattern eq 'list') {
        my @sub_descs = map { $self->_field_to_english($_) } @{$field->{sub_patterns}};
        return join(', ', @sub_descs);
    } elsif ($pattern eq 'last') {
        return $field->{offset} ? "last day minus $field->{offset}" : "last day";
    } elsif ($pattern eq 'last_weekday') {
        return "last weekday";
    } elsif ($pattern eq 'nearest_weekday') {
        return "nearest weekday to the $field->{day}";
    } elsif ($pattern eq 'nth') {
        my $nth = $field->{nth} == 1 ? 'first' : $field->{nth} == 2 ? 'second' : $field->{nth} == 3 ? 'third' : $field->{nth} == 4 ? 'fourth' : 'fifth';
        my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday');
        return "$nth $dow_names{$field->{day}}";
    } elsif ($pattern eq 'last_of_day') {
        my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday');
        return "last $dow_names{$field->{day}}";
    }
    return "every $type";
}

sub is_match {
    my ($self, $epoch_seconds) = @_;
    print STDERR "DEBUG: Checking is_match for epoch $epoch_seconds\n";
    return 0 if @{$self->{errors}};
    # Convert epoch to time parts in the specified time zone
    my $dt;
    eval {
        $dt = DateTime->from_epoch(epoch => $epoch_seconds, time_zone => $self->{time_zone});
    };
    if ($@) {
        warn "Invalid epoch or time zone: $@";
        print STDERR "DEBUG: Error: Invalid epoch or time zone\n";
        return 0;
    }
    my %time_parts = (
        seconds => $dt->second,
        minute => $dt->minute,
        hour => $dt->hour,
        dom => $dt->day,
        month => $dt->month,
        dow => $dt->day_of_week % 7, # Convert 1-7 to 0-6
        year => $dt->year,
    );
    print STDERR "DEBUG: Time parts: " . join(", ", map { "$_=$time_parts{$_}" } keys %time_parts) . "\n";
    for my $field (@{$self->{fields}}) {
        my $type = $field->{field_type};
        my $val = $time_parts{$type};
        my $matches = $field->matches(\%time_parts);
        print STDERR "DEBUG: Field $type value $val matches: $matches\n";
        return 0 unless $matches;
    }
    print STDERR "DEBUG: All fields match\n";
    return 1;
}

sub _field_matches {
    my ($self, $field, $time_parts) = @_;
    return $field->matches($time_parts);
}

sub _days_in_month {
    my ($self, $mon, $year) = @_;
    my $d = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[$mon];
    $d = 29 if $mon == 2 && $year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0);
    return $d;
}

sub _dow_of_date {
    my ($self, $year, $mon, $dom) = @_;
    my $dt = DateTime->new(year => $year, month => $mon, day => $dom, time_zone => $self->{time_zone});
    return $dt->day_of_week % 7; # Convert 1-7 to 0-6
}

sub _dump_field {
    my ($field) = @_;
    my @parts = ("type=" . ($field->{pattern_type} // 'unknown'));
    for my $key (qw(value min_value max_value start_value step offset day nth)) {
        push @parts, "$key=" . (exists $field->{$key} ? defined $field->{$key} ? $field->{$key} : 'undef' : 'undef');
    }
    if ($field->{sub_patterns}) {
        push @parts, "sub_patterns=[" . join(", ", map { _dump_field($_) } @{$field->{sub_patterns}}) . "]";
    }
    return "{" . join(", ", @parts) . "}";
}

1;
