package Cron::Describe::DayOfMonthPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';
use Time::Moment;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: DayOfMonthPattern::new: value='$value', field_type='$field_type'\n" if $Cron::Describe::DEBUG;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{is_special} = 1;
    if ($value eq 'L') {
        $self->{pattern_type} = 'last';
        $self->{offset} = 0;
    } elsif ($value eq 'LW') {
        $self->{pattern_type} = 'last_weekday';
        $self->{offset} = 0;
    } elsif ($value =~ /^(\d{1,2})W$/) {
        $self->{pattern_type} = 'nearest_weekday';
        $self->{day} = $1;
        if ($1 < 1 || $1 > $max) {
            $self->add_error("Day $1 is out of range for nearest weekday (1-$max)");
            croak $self->errors->[0];
        }
    } elsif ($value =~ /^L-(\d+)$/) {
        $self->{pattern_type} = 'last';
        $self->{offset} = $1;
        if ($1 >= $max) {
            $self->add_error("Offset $1 too large for last day of month");
            croak $self->errors->[0];
        }
    } else {
        $self->add_error("Invalid day-of-month pattern '$value' for $field_type");
        croak $self->errors->[0];
    }
    $self->validate();
    print STDERR "DEBUG: DayOfMonthPattern: pattern_type=$self->{pattern_type}, offset=" . ($self->{offset} // 'undef') . ", day=" . ($self->{day} // 'undef') . "\n" if $Cron::Describe::DEBUG;
    return $self;
}

sub validate {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'last') {
        unless ($self->{value} eq 'L' || $self->{value} =~ /^L-\d+$/) {
            $self->add_error("Invalid last day pattern '$self->{value}' for $self->{field_type}");
        }
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        unless ($self->{value} eq 'LW') {
            $self->add_error("Invalid last weekday pattern '$self->{value}' for $self->{field_type}");
        }
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        if (!defined $self->{day} || $self->{day} < 1 || $self->{day} > $self->{max}) {
            $self->add_error("Day " . ($self->{day} // 'undef') . " is out of range for nearest weekday (1-$self->{max})");
        }
    }
    croak join("; ", @{$self->errors}) if $self->has_errors;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $result = 0;
    if ($self->{pattern_type} eq 'last') {
        my $last_day = $tm->length_of_month;
        $result = $value == $last_day - ($self->{offset} // 0);
        $self->_debug("is_match: last, value=$value, last_day=$last_day, offset=" . ($self->{offset} // 0) . ", result=$result");
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $last_day = $tm->length_of_month;
        my $last_day_moment = Time::Moment->new(year => $tm->year, month => $tm->month, day => $last_day);
        my $dow = $last_day_moment->day_of_week % 7;
        my $target_day = $last_day;
        if ($dow == 0) { # Sunday
            $target_day -= 2; # Move to Friday
        } elsif ($dow == 6) { # Saturday
            $target_day -= 1; # Move to Friday
        }
        $result = $value == $target_day && $target_day >= 1 && $target_day <= $tm->length_of_month;
        $self->_debug("is_match: last_weekday, value=$value, target_day=$target_day, dow=$dow, result=$result");
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $target = $tm->with_day_of_month($self->{day});
        my $dow = $target->day_of_week % 7;
        my $target_day = $target->day_of_month;
        if ($dow == 0) { # Sunday
            $target_day += ($self->{day} < $tm->length_of_month) ? 1 : -2;
        } elsif ($dow == 6) { # Saturday
            $target_day += ($self->{day} > 1) ? -1 : 2;
        }
        $result = $value == $target_day && $target_day >= 1 && $target_day <= $tm->length_of_month;
        $self->_debug("is_match: nearest_weekday, value=$value, target_day=$target_day, dow=$dow, result=$result");
    }
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    $hash->{is_special} = $self->{is_special};
    $hash->{offset} = $self->{offset} if defined $self->{offset};
    $hash->{day} = $self->{day} if defined $self->{day};
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return $self->{value};
}

sub to_english {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'last') {
        return $self->{offset} ? "last day minus $self->{offset}" : "last day";
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        return "last weekday";
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        return "nearest weekday to day $self->{day}";
    }
    return "";
}

1;
