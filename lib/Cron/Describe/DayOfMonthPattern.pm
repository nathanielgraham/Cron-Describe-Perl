
package Cron::Describe::DayOfMonthPattern;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;
use parent 'Cron::Describe::Pattern';
use Cron::Describe::Utils qw(:all);

sub to_english {
    my ($self, $is_midnight) = @_;
    if ($self->{pattern_type} eq 'last_weekday') {
        return $self->{is_midnight} ? 'last weekday of the month' : 'last weekday of every month';
    }
    if ($self->{pattern_type} eq 'last' && $self->{offset} == 0) {
        return $self->{is_midnight} ? 'last day of the month' : 'last day of every month';
    }
    if ($self->{pattern_type} eq 'last' && $self->{offset}) {
        return num_to_ordinal(abs($self->{offset})) . " last day of every month";
    }
    if ($self->{pattern_type} eq 'nth_last') {
        return num_to_ordinal($self->{nth}) . " last day of every month";
    }
    return $self->{value} || '';
}

sub is_midnight {
    my ($self) = @_;
    return $self->{hour} == 0 && $self->{minute} == 0 && $self->{second} == 0;
}

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my ($pattern_type, $offset, $day);

    if ($value =~ /^L(-\d+)?$/) {
        $pattern_type = 'last';
        $offset = $1 // 0;
    } elsif ($value =~ /^(\d+)W$/) {
        $pattern_type = 'nearest_weekday';
        $day = $1;
        croak "Day $day is out of range for nearest weekday ($min-$max)" unless $day >= $min && $day <= $max;
    } elsif ($value eq 'LW') {
        $pattern_type = 'last_weekday';
    } else {
        croak "Invalid pattern '$value' for $field_type";
    }
    my $nth = $pattern_type eq 'last' && $offset ? abs($offset) : 0;
    my $self = bless {
        value => $value,
        min => $min,
        max => $max,
        field_type => $field_type,
        pattern_type => $pattern_type,
        offset => $offset,
        day => $day,
        nth => $nth,
    }, $class;

    print STDERR "DEBUG: DayOfMonthPattern::new: value='$value', field_type='$field_type', pattern_type=$pattern_type, offset=" . ($offset // 'undef') . ", day=" . ($day // 'undef') . "\n" if $ENV{Cron_DEBUG};
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    croak "Time::Moment object required" unless ref($tm) eq 'Time::Moment';

    print STDERR "DEBUG: DayOfMonthPattern::is_match: input_time=" . $tm->strftime('%Y-%m-%d %H:%M:%S %Z') . ", year=" . $tm->year . ", month=" . $tm->month . "\n" if $ENV{Cron_DEBUG};
    my $last_day = $tm->at_last_day_of_month->day_of_month;
    my $match_day;

    if ($self->{pattern_type} eq 'last') {
        $match_day = $last_day + $self->{offset};
        print STDERR "DEBUG: DayOfMonthPattern::is_match: pattern_type=last, value=$value, last_day=$last_day, offset=$self->{offset}, match_day=$match_day\n" if $ENV{Cron_DEBUG};
        my $result = $value == $match_day;
        print STDERR "DEBUG: DayOfMonthPattern::is_match: result=" . ($result ? 'true' : 'false') . " for value=$value, match_day=$match_day\n" if $ENV{Cron_DEBUG};
        return $result;
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $day = $self->{day};
        my $tm_day = $tm->with_day_of_month($day);
        my $dow = $tm_day->day_of_week;
        my $adjusted_day = $day;
        if ($dow == 6) { # Saturday
            $adjusted_day = $day - 1 if $day > 1;
        } elsif ($dow == 7) { # Sunday
            $adjusted_day = $day + 1 if $day < $last_day;
        }
        print STDERR "DEBUG: DayOfMonthPattern::is_match: pattern_type=nearest_weekday, value=$value, day=$day, dow=$dow, adjusted_day=$adjusted_day, tm_day=" . $tm_day->strftime('%Y-%m-%d') . "\n" if $ENV{Cron_DEBUG};
        my $result = $value == $adjusted_day;
        print STDERR "DEBUG: DayOfMonthPattern::is_match: result=" . ($result ? 'true' : 'false') . " for value=$value, adjusted_day=$adjusted_day\n" if $ENV{Cron_DEBUG};
        return $result;
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $day = $last_day;
        my $tm_last = $tm->at_last_day_of_month;
        my $dow = $tm_last->day_of_week;
        my $adjusted_day = $day;
        if ($dow == 6) { # Saturday
            $adjusted_day = $day - 1 if $day > 1;
        } elsif ($dow == 7) { # Sunday
            $adjusted_day = $day - 2 if $day > 2;
        }
        print STDERR "DEBUG: DayOfMonthPattern::is_match: pattern_type=last_weekday, value=$value, last_day=$day, dow=$dow, adjusted_day=$adjusted_day, tm_last=" . $tm_last->strftime('%Y-%m-%d') . "\n" if $ENV{Cron_DEBUG};
        my $result = $value == $adjusted_day;
        print STDERR "DEBUG: DayOfMonthPattern::is_match: result=" . ($result ? 'true' : 'false') . " for value=$value, adjusted_day=$adjusted_day\n" if $ENV{Cron_DEBUG};
        return $result;
    }
    print STDERR "DEBUG: DayOfMonthPattern::is_match: no matching pattern_type, returning false\n" if $ENV{Cron_DEBUG};
    return 0;
}

sub to_string {
    my ($self) = @_;
    return $self->{value};
}

sub to_hash {
    my ($self) = @_;
    return {
        value => $self->{value},
        field_type => $self->{field_type},
        pattern_type => $self->{pattern_type},
        offset => $self->{offset},
        day => $self->{day},
    };
}

1;
