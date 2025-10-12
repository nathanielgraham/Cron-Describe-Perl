package Cron::Describe::DayOfWeekPattern;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: Cron::Describe::DayOfWeekPattern: Cron::Describe::DayOfWeekPattern: value='$value', field_type='$field_type', min=$min, max=$max\n" if $ENV{Cron_DEBUG};

    my ($day, $nth, $pattern_type);
    if ($value =~ /^(\d+)#(\d+)$/) {
        ($day, $nth) = ($1, $2);
        $pattern_type = 'nth';
        croak "Day $day out of range for dow" if $day < $min || $day > $max;
        croak "Nth value $nth out of range (1-5)" if $nth < 1 || $nth > 5;
    } elsif ($value =~ /^(\d+)L$/) {
        $day = $1;
        $pattern_type = 'last_of_day';
        croak "Day $day out of range for dow" if $day < $min || $day > $max;
    } else {
        croak "Invalid day-of-week pattern '$value' for $field_type";
    }

    my $self = bless {
        value => $value,
        min => $min,
        max => $max,
        field_type => $field_type,
        pattern_type => $pattern_type,
        day => $day,
        nth => $nth,
    }, $class;
    return $self;
}

sub to_hash {
    my ($self) = @_;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => $self->{pattern_type},
        min => $self->{min},
        max => $self->{max},
        step => 1,
        day => $self->{day},
    };
    $hash->{nth} = $self->{nth} if defined $self->{nth};
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return $self->{value};
}

sub is_match {
    my ($self, $value, $tm) = @_;
    print STDERR "DEBUG: is_match: field=5, field_type=dow, value=$value, pattern=" . ref($self) . ", pattern_value=" . $self->to_string . "\n" if $ENV{Cron_DEBUG};
    if ($self->{pattern_type} eq 'nth') {
        my $week_of_month = int(($tm->day_of_month - 1) / 7) + 1;
        return $value == $self->{day} && $week_of_month == $self->{nth};
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        my $days_in_month = $tm->length_of_month;
        my $last_day = $tm->with_day_of_month($days_in_month);
        while ($last_day->day_of_month >= 1) {
            if (Cron::Describe::quartz_dow($last_day->day_of_week) == $self->{day}) {
                last;
            }
            $last_day = $last_day->minus_days(1);
        }
        return $value == $self->{day} && $tm->day_of_month == $last_day->day_of_month;
    }
    return 0;
}

1;
