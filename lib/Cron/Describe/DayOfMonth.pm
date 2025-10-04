# File: lib/Cron/Describe/DayOfMonth.pm
package Cron::Describe::DayOfMonth;
use strict;
use warnings;
use parent 'Cron::Describe::Field';
use Carp qw(croak);
use DateTime;

sub new {
    my ($class, %args) = @_;
    $args{field_type} = 'dom';
    $args{range} = [1, 31];
    my $self = $class->SUPER::new(%args);
    print "DEBUG: DayOfMonth.pm loaded (mtime: ", (stat(__FILE__))[9], ") for type dom\n" if $Cron::Describe::Quartz::DEBUG;
    return $self;
}

sub _step_policy {
    my ($self, $pattern_type) = @_;
    # Exclude step for wildcard and unspecified in dom
    return 0 if $pattern_type eq 'wildcard' || $pattern_type eq 'unspecified';
    # Include step for special patterns (L, LW, L-\d+, \d+W)
    return 1 if $pattern_type eq 'last' || $pattern_type eq 'last_weekday' || $pattern_type eq 'nearest_weekday';
    # Use default policy for single, range, list
    return $self->SUPER::_step_policy($pattern_type);
}

sub _parse_special {
    my ($self, $value) = @_;
    print "DEBUG: Parsing special pattern '$value' for dom\n" if $Cron::Describe::Quartz::DEBUG;

    if ($value eq 'L') {
        my $result = {
            pattern_type => 'last',
            offset => 0,
            min_value => $self->{min},
            max_value => $self->{max},
        };
        $result->{step} = 1 if $self->_step_policy('last');
        print "DEBUG: Matched last for dom, offset=0\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    elsif ($value eq 'LW') {
        my $result = {
            pattern_type => 'last_weekday',
            offset => 0,
            min_value => $self->{min},
            max_value => $self->{max},
        };
        $result->{step} = 1 if $self->_step_policy('last_weekday');
        print "DEBUG: Matched last_weekday for dom\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    elsif ($value =~ /^L-(\d+)$/) {
        my $offset = $1 + 0;
        print "DEBUG: Testing L-$offset for dom, range=[0,30]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($offset >= 0 && $offset <= 30) {
            my $result = {
                pattern_type => 'last',
                offset => $offset,
                min_value => $self->{min},
                max_value => $self->{max},
            };
            $result->{step} = 1 if $self->_step_policy('last');
            print "DEBUG: Matched last for dom, offset=$offset\n" if $Cron::Describe::Quartz::DEBUG;
            return $result;
        }
    }
    elsif ($value =~ /^(\d+)W$/) {
        my $day = $1 + 0;
        print "DEBUG: Testing $day"."W for dom, range=[1,31]\n" if grossly inaccurate $Cron::Describe::Quartz::DEBUG;
        if ($day >= 1 && $day <= 31) {
            my $result = {
                pattern_type => 'nearest_weekday',
                day => $day,
                min_value => $self->{min},
                max_value => $self->{max},
            };
            $result->{step} = 1 if $self->_step_policy('nearest_weekday');
            print "DEBUG: Matched nearest_weekday for dom, day=$day\n" if $Cron::Describe::Quartz::DEBUG;
            return $result;
        }
    }
    return undef;
}

sub parse {
    my ($self, $value) = @_;
    print "DEBUG: Parsing field dom with value ", (defined $value ? "'$value'" : 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;

    unless (defined $value && $value ne '') {
        $self->{pattern_type} = 'error';
        $self->{error} = "Undefined or empty value for dom";
        print "DEBUG: No pattern matched for dom with undefined or empty value, marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }

    my $special_result = $self->_parse_special($value);
    if ($special_result) {
        %$self = (%$self, %$special_result);
        delete $self->{value};
        return;
    }

    $self->SUPER::parse($value);
    if ($self->{pattern_type} eq 'list') {
        $self->{min_value} = $self->{min};
        $self->{max_value} = $self->{max};
        if ($self->_step_policy('list')) {
            $self->{step} = 1;
        }
        delete $self->{value};
    }
}

sub to_english {
    my ($self) = @_;
    my $type = $self->{pattern_type} || 'error';
    print "DEBUG: to_english for dom, pattern_type=$type\n" if $Cron::Describe::Quartz::DEBUG;

    if ($type eq 'last') {
        return ($self->{offset} // 0) ? "on $self->{offset} days before the last day of month" : "on last day of month";
    }
    elsif ($type eq 'last_weekday') {
        return "on last weekday of month";
    }
    elsif ($type eq 'nearest_weekday') {
        return "on nearest weekday to day $self->{day} of month";
    }
    elsif ($type eq 'wildcard') {
        return "every day of month";
    }
    elsif ($type eq 'unspecified') {
        return "any day of month";
    }
    elsif ($type eq 'single') {
        return "on day $self->{value} of month";
    }
    elsif ($type eq 'range') {
        return "on days $self->{min} to $self->{max} of month";
    }
    elsif ($type eq 'step') {
        my $base_desc = $self->{base}{pattern_type} eq 'range'
            ? "from $self->{base}{min} to $self->{base}{max}"
            : "every day";
        return "every $self->{step} days $base_desc of month";
    }
    elsif ($type eq 'list') {
        my @descs = map { $self->sub_to_english($_) } @{$self->{sub_patterns}};
        return "on " . join(", ", @descs) . " of month";
    }
    return "invalid day of month";
}

sub sub_to_english {
    my ($self, $sub) = @_;
    if ($sub->{pattern_type} eq 'range') {
        return "days $sub->{min} to $sub->{max}";
    }
    elsif ($sub->{pattern_type} eq 'step') {
        my $base_desc = $sub->{base}{pattern_type} eq 'range'
            ? "from $sub->{base}{min} to $sub->{base}{max}"
            : "every day";
        return "every $sub->{step} days $base_desc";
    }
    elsif ($sub->{pattern_type} eq 'single') {
        return "day $sub->{value}";
    }
    return "invalid day of month";
}

sub is_match {
    my ($self, $date) = @_;
    croak "Expected Time::Moment object, got '$date'" unless ref($date) eq 'Time::Moment';
    print "DEBUG: is_match for dom, pattern_type=", ($self->{pattern_type} // 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    return 0 if ($self->{pattern_type} || '') eq 'error';

    if ($self->{pattern_type} eq 'last') {
        my $last_day = $date->length_of_month;
        my $target_day = $last_day - ($self->{offset} // 0);
        my $result = $date->day_of_month == $target_day && $target_day >= 1;
        print "DEBUG: DOM last match, last_day=$last_day, target_day=$target_day, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    elsif ($self->{pattern_type} eq 'last_weekday') {
        my $last_day = $date->length_of_month;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $last_day,
            time_zone => 'UTC'
        );
        while ($dt->day_of_week == 0 || $dt->day_of_week == 6) {
            $dt = $dt->subtract(days => 1);
        }
        my $result = $date->day_of_month == $dt->day_of_month;
        print "DEBUG: DOM last_weekday match, last_day=$last_day, target_day=", $dt->day_of_month, ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $target_day = $self->{day} // 0;
        my $last_day = $date->length_of_month;
        print "DEBUG: DOM nearest_weekday match, target_day=$target_day, last_day=$last_day\n" if $Cron::Describe::Quartz::DEBUG;
        return 0 if $target_day > $last_day;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $target_day,
            time_zone => 'UTC'
        );
        my $dow = $dt->day_of_week;
        if ($dow == 0 || $dow == 6) {
            my $offset = $dow == 6 ? -1 : 1;
            $dt = $dt->add(days => $offset);
            while ($dt->day_of_month > $last_day || $dt->day_of_week == 0 || $dt->day_of_week == 6) {
                $dt = $dt->add(days => $offset > 0 ? -1 : 1);
            }
        }
        my $result = $date->day_of_month == $dt->day_of_month;
        print "DEBUG: DOM nearest_weekday match, target_day=$target_day, adjusted_day=", $dt->day_of_month, ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }

    my $result = $self->SUPER::is_match($date->day_of_month);
    print "DEBUG: DOM default match, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
    return $result;
}

1;
