# File: lib/Cron/Describe/Base.pm
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
       
        my $range = $field_type eq 'seconds' ? [0, 59] :
                    $field_type eq 'minute' ? [0, 59] :
                    $field_type eq 'hour' ? [0, 23] :
                    $field_type eq 'dom' ? [1, 31] :
                    $field_type eq 'month' ? [1, 12] :
                    $field_type eq 'dow' ? [0, 7] :
                    $field_type eq 'year' ? [1970, 2199] : [0, 59];
        print "DEBUG: Setting range for $field_type: [", join(", ", @$range), "]\n" if $self->{debug};
       
        my $field = $field_class->new(
            field_type => $field_type,
            value => $field_value,
            range => $range
        );
        $field->parse($field_value) if defined $field_value;
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
   
    my $is_quartz = $self->{type} eq 'quartz';
    my $field_offset = 0;
    my $seconds = $is_quartz ? $self->{fields}->[0] : undef;
    my $minutes = $self->{fields}->[$field_offset];
    my $hours = $self->{fields}->[$field_offset + 1];
    my $dom = $self->{fields}->[$field_offset + 2];
    my $month = $self->{fields}->[$field_offset + 3];
    my $dow = $self->{fields}->[$field_offset + 4];
    my $year = @{$self->{fields}} > ($is_quartz ? 6 : 5) ? $self->{fields}->[$is_quartz ? 6 : 5] : undef;
   
    print "DEBUG: to_english: type=$self->{type}, field_offset=$field_offset, field_count=", scalar(@{$self->{fields}}), "\n" if $self->{debug};
   
    # Build time part
    my $time_part = "";
    if ($is_quartz) {
        my $sec_val = ($seconds && ($seconds->{pattern_type} // '') eq 'single' && defined $seconds->{value}) ? $seconds->{value} : 0;
        my $min_val = ($minutes && ($minutes->{pattern_type} // '') eq 'single' && defined $minutes->{value}) ? $minutes->{value} : 0;
        my $hour_val = ($hours && ($hours->{pattern_type} // '') eq 'single' && defined $hours->{value}) ? $hours->{value} : 0;
        if ($sec_val == 0 && $min_val == 0 && $hour_val == 0) {
            $time_part = "00:00:00";
        } else {
            $time_part = sprintf("%02d:%02d:%02d", $sec_val, $min_val, $hour_val);
        }
    } else {
        my $min_val = ($minutes && ($minutes->{pattern_type} // '') eq 'single' && defined $minutes->{value}) ? $minutes->{value} : 0;
        my $hour_val = ($hours && ($hours->{pattern_type} // '') eq 'single' && defined $hours->{value}) ? $hours->{value} : 0;
        if ($min_val == 0 && $hour_val == 0) {
            $time_part = "00:00";
        } else {
            $time_part = sprintf("%02d:%02d", $min_val, $hour_val);
        }
    }
    push @parts, "at $time_part";
   
    # Delegate to field-specific to_english
    my $dom_desc = $dom->to_english;
    push @parts, $dom_desc =~ /invalid/ ? "every day of month" : $dom_desc;
    my $month_desc = $month->to_english;
    push @parts, $month_desc =~ /invalid/ ? "in every month" : "in $month_desc";
    my $dow_desc = $dow->to_english;
    push @parts, $dow_desc =~ /invalid/ ? "every day-of-week" : $dow_desc;
    if ($year && ($year->{pattern_type} // '') ne 'error') {
        my $year_desc = $year->to_english;
        push @parts, $year_desc =~ /invalid/ ? "every year" : "in $year_desc";
    }
   
    my $result = "Runs " . join(", ", grep { $_ } @parts);
    print "DEBUG: to_english: final result='$result'\n" if $self->{debug};
    return $result;
}

1;
