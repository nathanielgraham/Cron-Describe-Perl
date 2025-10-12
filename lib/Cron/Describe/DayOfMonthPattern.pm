package Cron::Describe::DayOfMonthPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = '';
    $self->_debug("DayOfMonthPattern::new: value='$value', field_type='$field_type'");
    if ($value eq 'L') {
        $self->{pattern_type} = 'last';
        $self->{offset} = 0;
    } elsif ($value eq 'LW') {
        $self->{pattern_type} = 'last_weekday';
        $self->{offset} = 0;
    } elsif ($value =~ /^(\d+)W$/) {
        $self->{pattern_type} = 'nearest_weekday';
        $self->{day} = $1;
        croak "Day $1 is out of range for nearest weekday (1-$max)" if $1 < $min || $1 > $max;
    } elsif ($value =~ /^L-(\d+)$/) {
        $self->{pattern_type} = 'last';
        $self->{offset} = $1;
        croak "Offset $1 is too large for $field_type" if $1 >= $max;
    } else {
        croak "Invalid day-of-month pattern '$value' for $field_type";
    }
    $self->_debug("DayOfMonthPattern: pattern_type=$self->{pattern_type}, offset=" . ($self->{offset} // 'undef') . ", day=" . ($self->{day} // 'undef'));
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    if ($self->{pattern_type} eq 'last') {
        my $last_day = $tm->length_of_month;
        return $value == $last_day - $self->{offset};
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $last_day = $tm->length_of_month;
        my $last_tm = $tm->with_day_of_month($last_day);
        my $dow = $last_tm->day_of_week;
        $dow = 7 if $dow == 0; # Map Sunday to 7
        if ($dow == 6 || $dow == 7) { # Saturday or Sunday
            return $value == $last_day - ($dow == 6 ? 1 : 2);
        }
        return $value == $last_day;
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $target_day = $self->{day};
        my $tm_day = $tm->with_day_of_month($target_day);
        my $dow = $tm_day->day_of_week;
        $dow = 7 if $dow == 0;
        if ($dow == 6 || $dow == 7) { # Saturday or Sunday
            my $offset = $dow == 6 ? -1 : ($tm_day->day_of_month == 1 ? 1 : -1);
            return $value == $target_day + $offset;
        }
        return $value == $target_day;
    }
    return 0;
}

sub to_english {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'last') {
        return $self->{offset} ? "the $self->{offset}th-to-last day of the month" : "the last day of the month";
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        return "the last weekday of the month";
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        return "the nearest weekday to the $self->{day}th";
    }
    return "unknown";
}

sub to_string {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'last') {
        return $self->{offset} ? "L-$self->{offset}" : 'L';
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        return 'LW';
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        return "$self->{day}W";
    }
    return $self->{value} // '';
}

sub to_hash {
    my ($self) = @_;
    my $hash = $self->SUPER::to_hash;
    $hash->{offset} = $self->{offset} if defined $self->{offset};
    $hash->{day} = $self->{day} if defined $self->{day};
    return $hash;
}

1;
