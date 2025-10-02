package Cron::Describe::Standard;
use strict;
use warnings;
use parent 'Cron::Describe::Base';
use Cron::Describe::Field;
use Cron::Describe::DayOfMonth;
use Cron::Describe::DayOfWeek;
use POSIX 'mktime';
use DateTime::TimeZone;

# ABSTRACT: Standard cron expression parser and validator

sub max { my ($a, $b) = @_; $a > $b ? $a : $b; }
sub min { my ($a, $b) = @_; $a < $b ? $a : $b; }

sub _parse_expression {
    my ($self, $expr) = @_;
    $expr = uc $expr;
    $expr =~ s/\s+/ /g;
    $expr =~ s/^\s+|\s+$//g;
    my @raw_fields = split /\s+/, $expr;
    if (@raw_fields != 5) {
        push @{$self->{errors}}, "Invalid field count: got " . @raw_fields . ", expected 5";
        die "Invalid field count: got " . @raw_fields . ", expected 5";
    }
    my @field_types = qw(minute hour dom month dow);
    my $fields = [];
    for my $i (0 .. $#raw_fields) {
        my $type = $field_types[$i];
        my $field_args = { field_type => $type, raw_value => $raw_fields[$i] };
        if ($type eq 'minute') { $field_args->{min} = 0; $field_args->{max} = 59; }
        elsif ($type eq 'hour') { $field_args->{min} = 0; $field_args->{max} = 23; }
        elsif ($type eq 'dom') { $field_args->{min} = 1; $field_args->{max} = 31; }
        elsif ($type eq 'month') { $field_args->{min} = 1; $field_args->{max} = 12; }
        elsif ($type eq 'dow') { $field_args->{min} = 0; $field_args->{max} = 7; }
        my $field_class = $type eq 'dom' ? 'Cron::Describe::DayOfMonth' :
                          $type eq 'dow' ? 'Cron::Describe::DayOfWeek' :
                          'Cron::Describe::Field';
        my $field = $self->_parse_field($raw_fields[$i], $type, $field_args->{min}, $field_args->{max});
        $field = $field_class->new(%$field);
        push @$fields, $field;
    }
    return { map { $_->{field_type} => $_ } @$fields };
}

sub _parse_field {
    my ($self, $value, $type, $min, $max) = @_;
    my $field = { field_type => $type, min => $min, max => $max, raw_value => $value };
    if ($type eq 'month' || $type eq 'dow') {
        if ($value =~ /,/) {
            my @names = split /,/, $value;
            my @sub_patterns;
            for my $name (@names) {
                my $num = $self->_name_to_num($name, $type);
                if (!defined $num) {
                    push @{$self->{errors}}, "Invalid name $name for $type";
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
        } else {
            my $num = $self->_name_to_num($value, $type);
            if (defined $num) {
                return { field_type => $type, pattern_type => 'single', value => $num, min_value => $num, max_value => $num, step => 1, min => $min, max => $max };
            }
        }
    }
    my @parts = split /,/, $value;
    if (@parts > 1) {
        my @sub_patterns;
        for my $part (@parts) {
            $part =~ s/^\s+|\s+$//g;
            my $sub_field = $self->_parse_single_part($part, $type, $min, $max);
            push @sub_patterns, $sub_field;
            if ($sub_field->{pattern_type} eq 'error') {
                push @{$self->{errors}}, "Invalid format: $part for $type";
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
    if ($part eq '*') {
        $field->{pattern_type} = 'wildcard';
        return $field;
    } elsif ($part =~ /^(-?\d+)$/) {
        my $value = $1;
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
            $field_data->{pattern_type} = 'error';
        } else {
            $field_data->{pattern_type} = 'single';
        }
        return $field_data;
    } elsif ($part =~ /^(\d+)-(\d+)(?:\/(\d+))?$/) {
        my ($min_val, $max_val, $step) = ($1, $2, $3 // 1);
        if ($min_val < $min || $max_val > $max || $step <= 0) {
            push @{$self->{errors}}, "Out of bounds: $part for $type";
            return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
        }
        return { field_type => $type, pattern_type => 'range', min_value => $min_val, max_value => $max_val, step => $step, min => $min, max => $max };
    } elsif ($part =~ /^\*\/(\d+)$/) {
        my $step = $1;
        if ($step <= 0) {
            push @{$self->{errors}}, "Invalid step: $part for $type";
            return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
        }
        return { field_type => $type, pattern_type => 'step', start_value => $min, min_value => $min, max_value => $max, step => $step, min => $min, max => $max };
    } elsif ($part =~ /^(\d+)\/(\d+)$/) {
        my ($start, $step) = ($1, $2);
        if ($start < $min || $start > $max || $step <= 0) {
            push @{$self->{errors}}, "Out of bounds: $part for $type";
            return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
        }
        return { field_type => $type, pattern_type => 'step', start_value => $start, min_value => $start, max_value => $max, step => $step, min => $min, max => $max };
    }
    push @{$self->{errors}}, "Invalid format: $part for $type";
    return { field_type => $type, pattern_type => 'error', min => $min, max => $max };
}

sub _name_to_num {
    my ($self, $name, $type) = @_;
    if ($type eq 'month') {
        my %months = (
            JAN=>1, FEB=>2, MAR=>3, APR=>4, MAY=>5, JUN=>6,
            JUL=>7, AUG=>8, SEP=>9, OCT=>10, NOV=>11, DEC=>12
        );
        return $months{$name};
    } elsif ($type eq 'dow') {
        my %dow = (
            SUN=>0, MON=>1, TUE=>2, WED=>3, THU=>4, FRI=>5, SAT=>6,
            SUNDAY=>0, MONDAY=>1, TUESDAY=>2, WEDNESDAY=>3, THURSDAY=>4, FRIDAY=>5, SATURDAY=>6
        );
        return $dow{$name};
    }
    return undef;
}

sub is_valid {
    my ($self) = @_;
    if (@{$self->{errors}}) {
        return 0;
    }
    my $month_field = $self->{fields}{month};
    my $dom_field = $self->{fields}{dom};
    my @month_values = $month_field->{pattern_type} eq 'single' ? ($month_field->{value})
                     : $month_field->{pattern_type} eq 'list' ? map { $_->{value} } @{$month_field->{sub_patterns}}
                     : (1..12);
    my $is_wild_month = $month_field->{pattern_type} eq 'wildcard';
    my $is_wild_dom = $dom_field->{pattern_type} eq 'wildcard';
    my $max_dom = $is_wild_dom ? 31
                : $dom_field->{pattern_type} eq 'single' ? $dom_field->{value}
                : $dom_field->{pattern_type} eq 'range' || $dom_field->{pattern_type} eq 'step' ? $dom_field->{max_value}
                : $dom_field->{pattern_type} eq 'list' ? $self->max(map { $_->{pattern_type} eq 'single' ? $_->{value} : $_->{max_value} } @{$dom_field->{sub_patterns}})
                : 31;
    if ($max_dom > 31) {
        push @{$self->{errors}}, "Invalid DOM: max DOM $max_dom exceeds possible days";
        return 0;
    } elsif (!$is_wild_month && !$is_wild_dom) {
        my $max_valid_days = $self->max(map { $self->_days_in_month($_, undef) } @month_values);
        if ($max_dom > $max_valid_days) {
            push @{$self->{errors}}, "Invalid DOM for months [" . join(",", @month_values) . "]: max DOM $max_dom exceeds $max_valid_days days";
            return 0;
        }
    }
    for my $field (values %{$self->{fields}}) {
        if ($field->{pattern_type} eq 'range' || $field->{pattern_type} eq 'step') {
            if ($field->{step} <= 0) {
                push @{$self->{errors}}, "Invalid step 0 for $field->{field_type}";
                return 0;
            }
        }
        if ($field->{pattern_type} eq 'list') {
            for my $sub (@{$field->{sub_patterns}}) {
                if ($sub->{step} <= 0) {
                    push @{$self->{errors}}, "Invalid sub-step 0 for $field->{field_type}";
                    return 0;
                }
            }
        }
    }
    return 1;
}

sub to_english {
    my ($self) = @_;
    my @descs;
    for my $field (qw(minute hour dom month dow)) {
        my $f = $self->{fields}{$field};
        my $expand_steps = ($f->{field_type} eq 'minute') ? 1 : 0;
        my $desc = $f->to_english(expand_steps => $expand_steps);
        if ($f->{field_type} eq 'dow' && $f->{pattern_type} eq 'list') {
            my @days = map { $_->{value} } @{$f->{sub_patterns}};
            my %dow = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday');
            $desc = join(',', map { $dow{$_} } @days);
        } elsif ($f->{field_type} eq 'minute' && $f->{pattern_type} eq 'list') {
            $desc = join(',', map { sprintf("%02d", $_->{value}) } @{$f->{sub_patterns}}) . ' minutes past';
        } elsif ($f->{field_type} eq 'hour' && $f->{pattern_type} eq 'range') {
            $desc = sprintf("every hour from %02d through %02d", $f->{min_value}, $f->{max_value});
        } elsif ($f->{field_type} eq 'minute' && $f->{pattern_type} eq 'step') {
            $desc = sprintf("every %dth minute past", $f->{step});
        }
        push @descs, $desc;
    }
    my @time_parts = @descs[0..1];
    for my $i (0..1) {
        if ($time_parts[$i] =~ /^every (minute|hour)$/) {
            $time_parts[$i] = '00';
        } elsif ($time_parts[$i] =~ /^every \d+ (minutes|hours) starting at (\d+)/) {
            $time_parts[$i] = sprintf("%02d", $2);
        } elsif ($time_parts[$i] =~ /^(\d+)$/) {
            $time_parts[$i] = sprintf("%02d", $1);
        }
    }
    my $time = sprintf("%s:%s", @time_parts);
    my @date_parts = @descs[2..4];
    for my $i (0..2) {
        $date_parts[$i] =~ s/every dom/every day-of-month/;
        $date_parts[$i] =~ s/every dow/every day-of-week/;
        $date_parts[$i] =~ s/(\d+)-(\d+)/sprintf("days-of-month %d through %d", $1, $2)/e if $date_parts[$i] =~ /^(\d+)-(\d+)$/;
        $date_parts[$i] =~ s/(\d+)/sprintf("day-of-month %d", $1)/e if $date_parts[$i] =~ /^(\d+)$/ && $i == 0;
    }
    return "Runs at $time on " . join(', ', @date_parts);
}

sub _days_in_month {
    my ($self, $mon, $year) = @_;
    my $d = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[$mon];
    $d = 29 if $mon == 2 && defined $year && $year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0);
    return $d;
}

1;
