package Cron::Describe::Base;
use strict;
use warnings;
use Carp qw(croak);
use DateTime;
use DateTime::TimeZone;
use Time::Moment;

sub new {
    my ($class, %args) = @_;
    my $expression = $args{expression} or croak "Expression is required";
    my $self = {
        expression => $expression,
        time_zone => $args{time_zone} || 'UTC',
        debug => $args{debug} || 0,
        fields => [],
        type => $args{type}, # Set by factory or explicit constructor
    };
    print "DEBUG: Base.pm loaded (mtime: ", (stat(__FILE__))[9], ")\n" if $self->{debug};
    bless $self, $class;
    $self->_parse();
    return $self;
}

sub _parse {
    my ($self) = @_;
    my $expression = $self->{expression};
    $expression =~ s/^\s+|\s+$//g;
    print "DEBUG: Normalized expression: '$expression'\n" if $self->{debug};
    
    my @fields = split /\s+/, $expression;
    print "DEBUG: Split into ", scalar(@fields), " fields: [", join(", ", map { defined $_ ? $_ : 'undef' } @fields), "]\n" if $self->{debug};
    
    my @expected_types = $self->{type} eq 'quartz' ?
        qw(seconds minute hour dom month dow year) :
        qw(minute hour dom month dow year);
    my $min_fields = $self->{type} eq 'quartz' ? 6 : 5;
    my $max_fields = $self->{type} eq 'quartz' ? 7 : 6;
    
    print "DEBUG: Expected field types: [", join(", ", @expected_types), "]\n" if $self->{debug};
    print "DEBUG: Checking field count, expected: $min_fields-$max_fields, got: ", scalar(@fields), "\n" if $self->{debug};
    if (@fields < $min_fields || @fields > $max_fields) {
        croak "Invalid number of fields: got ", scalar(@fields), ", expected $min_fields or $max_fields";
    }
    
    print "DEBUG: Field count valid, proceeding to parse fields\n" if $self->{debug};
    
    my @field_objects;
    for my $i (0 .. $#fields) {
        my $field_type = $expected_types[$i] || 'year';
        my $field_value = $fields[$i];
        print "DEBUG: Parsing field $i: $field_type with value ", (defined $field_value ? "'$field_value'" : 'undef'), "\n" if $self->{debug};
        
        my $field_class = $field_type eq 'dom' ? 'Cron::Describe::DayOfMonth' :
                         $field_type eq 'dow' ? 'Cron::Describe::DayOfWeek' :
                         'Cron::Describe::Field';
        eval "require $field_class";
        croak "Failed to load $field_class: $@" if $@;
        my $mtime = $INC{"$field_class.pm"} ? (stat($INC{"$field_class.pm"}))[9] : 'unknown';
        print "DEBUG: $field_class loaded (mtime: $mtime) for type $field_type\n" if $self->{debug};
        
        my $field = $field_class->new(
            field_type => $field_type,
            value => defined $field_value ? $field_value : '',
            range => $field_type eq 'seconds' ? [0, 59] :
                    $field_type eq 'minute' ? [0, 59] :
                    $field_type eq 'hour' ? [0, 23] :
                    $field_type eq 'dom' ? [1, 31] :
                    $field_type eq 'month' ? [1, 12] :
                    $field_type eq 'dow' ? [0, 7] :
                    $field_type eq 'year' ? [1970, 2199] : [0, 59]
        );
        push @field_objects, $field;
    }
    
    $self->{fields} = \@field_objects;
    print "DEBUG: Finished parsing loop, fields count: ", scalar(@field_objects), "\n" if $self->{debug};
}

sub is_valid {
    my ($self) = @_;
    print "DEBUG: Validating expression\n" if $self->{debug};
    
    for my $field (@{$self->{fields}}) {
        my $pattern_type = $field->{pattern_type} || '';
        print "DEBUG: Checking field $field->{field_type}, pattern_type=$pattern_type\n" if $self->{debug};
        return 0 if $pattern_type eq 'error';
    }
    
    my $dom = $self->{fields}->[$self->{type} eq 'quartz' ? 3 : 2];
    my $month = $self->{fields}->[$self->{type} eq 'quartz' ? 4 : 3];
    my $dow = $self->{fields}->[$self->{type} eq 'quartz' ? 5 : 4];
    
    if ($self->{type} eq 'quartz') {
        my $dom_pattern = $dom->{pattern_type} || '';
        my $dow_pattern = $dow->{pattern_type} || '';
        print "DEBUG: Quartz validation: DOM pattern=$dom_pattern, DOW pattern=$dow_pattern\n" if $self->{debug};
        if ($dom_pattern ne 'unspecified' && $dow_pattern ne 'unspecified') {
            my $valid_dom_types = $dom_pattern eq 'wildcard' || $dom_pattern eq 'list' ||
                                 $dom_pattern eq 'last' || $dom_pattern eq 'last_weekday' ||
                                 $dom_pattern eq 'nearest_weekday';
            my $valid_dow_types = $dow_pattern eq 'wildcard' || $dow_pattern eq 'list' ||
                                 $dow_pattern eq 'nth' || $dow_pattern eq 'last_of_day';
            if (!$valid_dom_types || !$valid_dow_types) {
                print "DEBUG: Both DOM and DOW specified without valid patterns, invalid\n" if $self->{debug};
                return 0;
            }
        }
        if ($dom_pattern eq 'unspecified' && $dow_pattern eq 'unspecified') {
            print "DEBUG: Neither DOM nor DOW specified, invalid\n" if $self->{debug};
            return 0;
        }
        print "DEBUG: DOM validation passed\n" if $self->{debug};
    }
    
    if (@{$self->{fields}} > ($self->{type} eq 'quartz' ? 6 : 5)) {
        my $year = $self->{fields}->[$self->{type} eq 'quartz' ? 6 : 5];
        my $year_pattern = $year->{pattern_type} || '';
        print "DEBUG: Checking year field, pattern_type=$year_pattern\n" if $self->{debug};
        if ($year_pattern eq 'error') {
            print "DEBUG: Invalid year field\n" if $self->{debug};
            return 0;
        }
    }
    
    print "DEBUG: Validation passed\n" if $self->{debug};
    return 1;
}

sub is_match {
    my ($self, $epoch) = @_;
    print "DEBUG: Checking for is_match in self: ", (exists $self->{is_match} ? "Found" : "Not found"), "\n" if $self->{debug};
    
    my $date = Time::Moment->from_epoch($epoch);
    for my $field (@{$self->{fields}}) {
        my $result = $field->is_match($date);
        print "DEBUG: is_match for field $field->{field_type}, pattern_type=", ($field->{pattern_type} // 'undef'), ", result=$result\n" if $self->{debug};
        return 0 unless $result;
    }
    return 1;
}

sub to_english {
    my ($self) = @_;
    my @parts;
    
    my $field_offset = $self->{type} eq 'quartz' ? 0 : 1;
    my $seconds = $self->{type} eq 'quartz' ? $self->{fields}->[0] : undef;
    my $minutes = $self->{fields}->[$field_offset];
    my $hours = $self->{fields}->[$field_offset + 1];
    my $dom = $self->{fields}->[$field_offset + 2];
    my $month = $self->{fields}->[$field_offset + 3];
    my $dow = $self->{fields}->[$field_offset + 4];
    my $year = @{$self->{fields}} > ($self->{type} eq 'quartz' ? 6 : 5) ? $self->{fields}->[$field_offset + 5] : undef;
    
    print "DEBUG: to_english: type=$self->{type}, field_offset=$field_offset\n" if $self->{debug};
    print "DEBUG: to_english: seconds pattern=", ($seconds ? $seconds->{pattern_type} // 'undef' : 'undef'), ", value=", ($seconds ? $seconds->{value} // 'undef' : 'undef'), "\n" if $self->{debug};
    print "DEBUG: to_english: minute pattern=", ($minutes->{pattern_type} // 'undef'), ", value=", ($minutes->{value} // 'undef'), "\n" if $self->{debug};
    print "DEBUG: to_english: hour pattern=", ($hours->{pattern_type} // 'undef'), ", value=", ($hours->{value} // 'undef'), "\n" if $self->{debug};
    print "DEBUG: to_english: dom pattern=", ($dom->{pattern_type} // 'undef'), ", sub_patterns=", ($dom->{sub_patterns} ? scalar(@{$dom->{sub_patterns}}) : 'none'), "\n" if $self->{debug};
    
    my $time_part = "";
    if ($self->{type} eq 'quartz') {
        if ($seconds && ($seconds->{pattern_type} || '') eq 'single') {
            $time_part = sprintf("%02d", $seconds->{value} // 0);
        } elsif ($seconds && ($seconds->{pattern_type} || '') eq 'range') {
            $time_part = sprintf("%d-%d", $seconds->{min_value} // 0, $seconds->{max_value} // 0);
        } elsif ($seconds && ($seconds->{pattern_type} || '') eq 'step') {
            $time_part = sprintf("%d/%d", $seconds->{start_value} // 0, $seconds->{step} // 1);
        } else {
            $time_part = "00";
        }
    }
    
    if (($minutes->{pattern_type} || '') eq 'single') {
        $time_part .= sprintf("%s%02d", $self->{type} eq 'quartz' ? ":" : "", $minutes->{value} // 0);
    } elsif (($minutes->{pattern_type} || '') eq 'range') {
        $time_part .= sprintf("%s%d-%d", $self->{type} eq 'quartz' ? ":" : "", $minutes->{min_value} // 0, $minutes->{max_value} // 0);
    } elsif (($minutes->{pattern_type} || '') eq 'step') {
        $time_part .= sprintf("%s%d/%d", $self->{type} eq 'quartz' ? ":" : "", $minutes->{start_value} // 0, $minutes->{step} // 1);
    } else {
        $time_part .= $self->{type} eq 'quartz' ? ":" : "";
        $time_part .= "00";
    }
    
    if (($hours->{pattern_type} || '') eq 'single') {
        $time_part .= sprintf(":%02d", $hours->{value} // 0);
    } elsif (($hours->{pattern_type} || '') eq 'range') {
        $time_part .= sprintf(":%d-%d", $hours->{min_value} // 0, $hours->{max_value} // 0);
    } elsif (($hours->{pattern_type} || '') eq 'step') {
        $time_part .= sprintf(":%d/%d", $hours->{start_value} // 0, $hours->{step} // 1);
    } else {
        $time_part .= ":00";
    }
    
    print "DEBUG: to_english: time_part=$time_part\n" if $self->{debug};
    push @parts, "at $time_part";
    
    if (($dom->{pattern_type} || '') eq 'single') {
        push @parts, sprintf("on day %d of month", $dom->{value} // 0);
        print "DEBUG: to_english: DOM single, value=$dom->{value}\n" if $self->{debug};
    } elsif (($dom->{pattern_type} || '') eq 'range') {
        push @parts, sprintf("on days %d to %d of month", $dom->{min_value} // 0, $dom->{max_value} // 0);
        print "DEBUG: to_english: DOM range, min_value=$dom->{min_value}, max_value=$dom->{max_value}\n" if $self->{debug};
    } elsif (($dom->{pattern_type} || '') eq 'step') {
        push @parts, sprintf("every %d days from %d of month", $dom->{step} // 1, $dom->{start_value} // 0);
        print "DEBUG: to_english: DOM step, start_value=$dom->{start_value}, step=$dom->{step}\n" if $self->{debug};
    } elsif (($dom->{pattern_type} || '') eq 'list') {
        my @sub_descs;
        for my $sub (@{$dom->{sub_patterns} || []}) {
            my $sub_pattern_type = $sub->{pattern_type} || '';
            print "DEBUG: to_english: DOM list sub_pattern, type=$sub_pattern_type\n" if $self->{debug};
            if ($sub_pattern_type eq 'single') {
                push @sub_descs, sprintf("day %d", $sub->{value} // 0);
                print "DEBUG: to_english: DOM list single, value=$sub->{value}\n" if $self->{debug};
            } elsif ($sub_pattern_type eq 'range') {
                push @sub_descs, sprintf("days %d to %d", $sub->{min_value} // 0, $sub->{max_value} // 0);
                print "DEBUG: to_english: DOM list range, min_value=$sub->{min_value}, max_value=$sub->{max_value}\n" if $self->{debug};
            } elsif ($sub_pattern_type eq 'step') {
                push @sub_descs, sprintf("every %d days from %d", $sub->{step} // 1, $sub->{start_value} // 0);
                print "DEBUG: to_english: DOM list step, start_value=$sub->{start_value}, step=$sub->{step}\n" if $self->{debug};
            }
        }
        push @parts, "on " . join(", ", @sub_descs) . " of month" if @sub_descs;
    } elsif (($dom->{pattern_type} || '') eq 'last') {
        push @parts, ($dom->{offset} // 0) ? sprintf("%d days before the last day of month", $dom->{offset}) : "on last day of month";
        print "DEBUG: to_english: DOM last, offset=", ($dom->{offset} // 0), "\n" if $self->{debug};
    } elsif (($dom->{pattern_type} || '') eq 'last_weekday') {
        push @parts, "on last weekday of month";
        print "DEBUG: to_english: DOM last_weekday\n" if $self->{debug};
    } elsif (($dom->{pattern_type} || '') eq 'nearest_weekday') {
        push @parts, sprintf("on nearest weekday to day %d of month", $dom->{day} // 0);
        print "DEBUG: to_english: DOM nearest_weekday, day=", ($dom->{day} // 0), "\n" if $self->{debug};
    } else {
        push @parts, "every day of month";
        print "DEBUG: to_english: DOM default (wildcard or unspecified)\n" if $self->{debug};
    }
    
    if (($month->{pattern_type} || '') eq 'single') {
        push @parts, sprintf("in month %d", $month->{value} // 0);
        print "DEBUG: to_english: month single, value=", ($month->{value} // 0), "\n" if $self->{debug};
    } elsif (($month->{pattern_type} || '') eq 'range') {
        push @parts, sprintf("in every month from %d to %d", $month->{min_value} // 0, $month->{max_value} // 0);
        print "DEBUG: to_english: month range, min_value=", ($month->{min_value} // 0), ", max_value=", ($month->{max_value} // 0), "\n" if $self->{debug};
    } elsif (($month->{pattern_type} || '') eq 'step') {
        push @parts, sprintf("every %d months from %d", $month->{step} // 1, $month->{start_value} // 0);
        print "DEBUG: to_english: month step, start_value=", ($month->{start_value} // 0), ", step=", ($month->{step} // 1), "\n" if $self->{debug};
    } else {
        push @parts, "in every month";
        print "DEBUG: to_english: month default\n" if $self->{debug};
    }
    
    if (($dow->{pattern_type} || '') eq 'single') {
        my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');
        push @parts, sprintf("on %s", $dow_names{$dow->{value} // 0});
        print "DEBUG: to_english: DOW single, value=", ($dow->{value} // 0), "\n" if $self->{debug};
    } elsif (($dow->{pattern_type} || '') eq 'range') {
        push @parts, sprintf("on every day-of-week from %d to %d", $dow->{min_value} // 0, $dow->{max_value} // 0);
        print "DEBUG: to_english: DOW range, min_value=", ($dow->{min_value} // 0), ", max_value=", ($dow->{max_value} // 0), "\n" if $self->{debug};
    } elsif (($dow->{pattern_type} || '') eq 'step') {
        push @parts, sprintf("every %d days-of-week from %d", $dow->{step} // 1, $dow->{start_value} // 0);
        print "DEBUG: to_english: DOW step, start_value=", ($dow->{start_value} // 0), ", step=", ($dow->{step} // 1), "\n" if $self->{debug};
    } elsif (($dow->{pattern_type} || '') eq 'list') {
        my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');
        my @sub_descs;
        for my $sub (@{$dow->{sub_patterns} || []}) {
            if (($sub->{pattern_type} || '') eq 'single' && defined $sub->{value}) {
                push @sub_descs, $dow_names{$sub->{value}};
                print "DEBUG: to_english: DOW list single, value=$sub->{value}\n" if $self->{debug};
            }
        }
        push @parts, "on " . join(", ", @sub_descs) if @sub_descs;
    } elsif (($dow->{pattern_type} || '') eq 'nth') {
        my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');
        my $nth = $dow->{nth} == 1 ? 'first' : $dow->{nth} == 2 ? 'second' : $dow->{nth} == 3 ? 'third' : $dow->{nth} == 4 ? 'fourth' : 'fifth';
        push @parts, sprintf("on the %s %s of month", $nth, $dow_names{$dow->{day} // 0});
        print "DEBUG: to_english: DOW nth, day=", ($dow->{day} // 0), ", nth=", ($dow->{nth} // 0), "\n" if $self->{debug};
    } elsif (($dow->{pattern_type} || '') eq 'last_of_day') {
        my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');
        push @parts, sprintf("on the last %s of month", $dow_names{$dow->{day} // 0});
        print "DEBUG: to_english: DOW last_of_day, day=", ($dow->{day} // 0), "\n" if $self->{debug};
    } else {
        push @parts, "every day-of-week";
        print "DEBUG: to_english: DOW default\n" if $self->{debug};
    }
    
    if ($year && ($year->{pattern_type} || '')) {
        if (($year->{pattern_type} || '') eq 'single') {
            push @parts, sprintf("in %d", $year->{value} // 0);
            print "DEBUG: to_english: year single, value=", ($year->{value} // 0), "\n" if $self->{debug};
        } elsif (($year->{pattern_type} || '') eq 'range') {
            push @parts, sprintf("in every year from %d to %d", $year->{min_value} // 0, $year->{max_value} // 0);
            print "DEBUG: to_english: year range, min_value=", ($year->{min_value} // 0), ", max_value=", ($year->{max_value} // 0), "\n" if $self->{debug};
        } elsif (($year->{pattern_type} || '') eq 'step') {
            push @parts, sprintf("every %d years from %d", $year->{step} // 1, $year->{start_value} // 0);
            print "DEBUG: to_english: year step, start_value=", ($year->{start_value} // 0), ", step=", ($year->{step} // 1), "\n" if $self->{debug};
        }
    }
    
    my $result = "Runs " . join(", ", @parts);
    print "DEBUG: to_english: final result='$result'\n" if $self->{debug};
    return $result;
}

1;
