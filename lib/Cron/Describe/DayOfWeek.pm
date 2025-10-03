# File: lib/Cron/Describe/DayOfWeek.pm
package Cron::Describe::DayOfWeek;
use strict;
use warnings;
use parent 'Cron::Describe::Field';
use Carp qw(croak);
use DateTime;

sub new {
    my ($class, %args) = @_;
    $args{field_type} = 'dow';
    $args{range} = [0, 7];
    my $self = $class->SUPER::new(%args);
    print "DEBUG: DayOfWeek.pm loaded (mtime: ", (stat(__FILE__))[9], ") for type dow\n" if $Cron::Describe::Quartz::DEBUG;
    return $self;
}

sub parse {
    my ($self, $value) = @_;
    print "DEBUG: Parsing field dow with value ", (defined $value ? "'$value'" : 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;

    unless (defined $value && $value ne '') {
        $self->{pattern_type} = 'error';
        $self->{error} = "Undefined or empty value for dow";
        print "DEBUG: No pattern matched for dow with undefined or empty value, marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }

    my %dow_map = (
        SUN => 0, MON => 1, TUE => 2, WED => 3, THU => 4, FRI => 5, SAT => 6
    );
    if (exists $dow_map{$value}) {
        $value = $dow_map{$value};
        print "DEBUG: Mapped dow name '$value' to numeric\n" if $Cron::Describe::Quartz::DEBUG;
    }

    if ($value eq '?' || $value eq '*') {
        $self->{pattern_type} = $value eq '?' ? 'unspecified' : 'wildcard';
        $self->{min_value} = $self->{min};
        $self->{max_value} = $self->{max};
        $self->{step} = 1;
        print "DEBUG: Matched ", ($value eq '?' ? 'unspecified' : 'wildcard'), " for dow\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    elsif ($value =~ /^(\d+)#(\d+)$/) {
        my ($day, $nth) = ($1 + 0, $2 + 0);
        print "DEBUG: Testing $day#$nth for dow, day range=[0,7], nth range=[1,5]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($day >= 0 && $day <= 7 && $nth >= 1 && $nth <= 5) {
            $self->{pattern_type} = 'nth';
            $self->{day} = $day;
            $self->{nth} = $nth;
            print "DEBUG: Matched nth for dow, day=$day, nth=$nth\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        }
    }
    elsif ($value =~ /^(\d+)L$/) {
        my $day = $1 + 0;
        print "DEBUG: Testing $day"."L for dow, range=[0,7]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($day >= 0 && $day <= 7) {
            $self->{pattern_type} = 'last_of_day';
            $self->{day} = $day;
            print "DEBUG: Matched last_of_day for dow, day=$day\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        }
    }

    $self->SUPER::parse($value);
}

sub to_english {
    my ($self) = @_;
    my $type = $self->{pattern_type} || 'error';
    print "DEBUG: to_english for dow, pattern_type=$type\n" if $Cron::Describe::Quartz::DEBUG;

    my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');
    if ($type eq 'nth') {
        my $nth = $self->{nth} == 1 ? 'first' : $self->{nth} == 2 ? 'second' : $self->{nth} == 3 ? 'third' : $self->{nth} == 4 ? 'fourth' : 'fifth';
        return "on the $nth $dow_names{$self->{day} // 0} of month";
    }
    elsif ($type eq 'last_of_day') {
        return "on the last $dow_names{$self->{day} // 0} of month";
    }
    elsif ($type eq 'single') {
        return "on $dow_names{$self->{value} // 0}";
    }
    return $self->SUPER::to_english;
}

sub is_match {
    my ($self, $date) = @_;
    croak "Expected Time::Moment object, got '$date'" unless ref($date) eq 'Time::Moment';
    print "DEBUG: is_match for dow, pattern_type=", ($self->{pattern_type} // 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    return 0 if ($self->{pattern_type} || '') eq 'error';

    if ($self->{pattern_type} eq 'nth') {
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => 1,
            time_zone => 'UTC'
        );
        my $dow = $dt->day_of_week % 7;
        my $target_day = $self->{day} // 0;
        my $first_occurrence = $target_day >= $dow ? $target_day - $dow + 1 : 8 - $dow + $target_day;
        my $nth_day = $first_occurrence + ($self->{nth} - 1) * 7;
        my $result = $date->day_of_month == $nth_day && $nth_day <= $date->length_of_month;
        print "DEBUG: DOW nth match, day=$self->{day}, nth=$self->{nth}, first_occurrence=$first_occurrence, nth_day=$nth_day, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    elsif ($self->{pattern_type} eq 'last_of_day') {
        my $last_day = $date->length_of_month;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $last_day,
            time_zone => 'UTC'
        );
        while ($dt->day_of_week % 7 != ($self->{day} // 0) && $dt->day_of_month >= 1) {
            $dt = $dt->subtract(days => 1);
        }
        my $result = $date->day_of_month == $dt->day_of_month;
        print "DEBUG: DOW last_of_day match, day=$self->{day}, target_day=", $dt->day_of_month, ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }

    my $result = $self->SUPER::is_match($date->day_of_week % 7);
    print "DEBUG: DOW default match, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
    return $result;
}

1;
