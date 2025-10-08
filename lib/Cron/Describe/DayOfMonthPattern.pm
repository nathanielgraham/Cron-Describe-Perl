package Cron::Describe::DayOfMonthPattern;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: DayOfMonthPattern::new: value='$value', field_type='$field_type'\n";
    croak "Invalid day-of-month pattern '$value' for $field_type" unless $value =~ /^(L|LW|(\d{1,2})W|L-\d+)$/;
    my $self = bless {}, $class;
    $self->{value} = $value;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;
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
        croak "Day $1 is out of range for nearest weekday (1-$max)" if $1 < 1 || $1 > $max;
    } elsif ($value =~ /^L-(\d+)$/) {
        $self->{pattern_type} = 'last';
        $self->{offset} = $1;
        croak "Offset $1 too large for last day of month" if $1 >= $max;
    }
    print STDERR "DEBUG: DayOfMonthPattern: pattern_type=$self->{pattern_type}, offset=" . ($self->{offset} // 'undef') . ", day=" . ($self->{day} // 'undef') . "\n";
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    if ($self->{pattern_type} eq 'last') {
        my $last_day = $tm->length_of_month;
        return $value == $last_day - $self->{offset};
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $last_day = $tm->with_day_of_month(1)->plus_months(1)->plus_days(-1);
        my $dow = $last_day->day_of_week % 7;
        my $target_day = ($dow == 0 || $dow == 6) ? $last_day->plus_days($dow == 0 ? -2 : -1)->day_of_month : $last_day->day_of_month;
        return $value == $target_day;
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $target = $tm->with_day_of_month($self->{day});
        my $dow = $target->day_of_week % 7;
        my $target_day = $target->day_of_month;
        if ($dow == 0 || $dow == 6) {
            my $direction = ($dow == 0 && $self->{day} != $tm->length_of_month) || ($dow == 6 && $self->{day} == 1) ? 1 : -1;
            $target_day = $target->plus_days($direction)->day_of_month;
        }
        return $value == $target_day && $target_day >= 1 && $target_day <= $tm->length_of_month;
    }
    return 0;
}

sub to_hash {
    my $self = shift;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => $self->{pattern_type},
        is_special => $self->{is_special},
        min => $self->{min},
        max => $self->{max},
        step => 1
    };
    $hash->{offset} = $self->{offset} if defined $self->{offset};
    $hash->{day} = $self->{day} if defined $self->{day};
    print STDERR "DEBUG: DayOfMonthPattern::to_hash: " . join(", ", map { "$_=$hash->{$_}" } keys %$hash) . "\n";
    return $hash;
}

1;
