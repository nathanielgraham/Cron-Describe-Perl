package Cron::Describe::DayOfMonth;
use strict;
use warnings;
use parent 'Cron::Describe::Field';
use Time::Moment;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    print STDERR "DEBUG: DayOfMonth.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $args{field_type}\n";
    return $self;
}

sub to_english {
    my ($self, %args) = @_;
    my $pattern = $self->{pattern_type};
    if ($pattern eq 'last') {
        return $self->{offset} ? "last day minus $self->{offset} days" : "last day of month";
    } elsif ($pattern eq 'nearest_weekday') {
        return "nearest weekday to day $self->{day}";
    } elsif ($pattern eq 'last_weekday') {
        return "last weekday of month";
    }
    return $self->SUPER::to_english(%args);
}

sub matches {
    my ($self, $time_parts) = @_;
    my $pattern = $self->{pattern_type};
    my $val = $time_parts->{dom};
    my $month = $time_parts->{month};
    my $year = $time_parts->{year} // 2025;
    print STDERR "DEBUG: Matching DOM value $val against pattern $pattern (month=$month, year=$year)\n" if $self->{parent}{debug};
    if ($pattern eq 'last') {
        my $days_in_month = $self->{parent}->_days_in_month($month, $year);
        return $val == $days_in_month - $self->{offset};
    } elsif ($pattern eq 'nearest_weekday') {
        my $target_day = $self->{day};
        my $days_in_month = $self->{parent}->_days_in_month($month, $year);
        return 0 if $target_day < 1 || $target_day > $days_in_month; # Invalid day
        my $tm = Time::Moment->new(year => $year, month => $month, day => $target_day);
        my $dow = $tm->day_of_week; # 1=Mon, 7=Sun
        # Adjust to nearest weekday (Mon-Fri)
        if ($dow == 7) { # Sunday
            $tm = $tm->plus_days(1); # Move to Monday
        } elsif ($dow == 6) { # Saturday
            $tm = $tm->minus_days(1); # Move to Friday
        }
        print STDERR "DEBUG: Field dom value $val matches: " . ($val == $tm->day_of_month ? 1 : 0) . "\n" if $self->{parent}{debug};
        return $val == $tm->day_of_month;
    } elsif ($pattern eq 'last_weekday') {
        my $days_in_month = $self->{parent}->_days_in_month($month, $year);
        my $tm = Time::Moment->new(year => $year, month => $month, day => $days_in_month);
        my $dow = $tm->day_of_week;
        # Adjust to last weekday (Mon-Fri)
        if ($dow == 7) { # Sunday
            $tm = $tm->minus_days(2); # Move to Friday
        } elsif ($dow == 6) { # Saturday
            $tm = $tm->minus_days(1); # Move to Friday
        }
        return $val == $tm->day_of_month;
    }
    return $self->SUPER::matches($time_parts);
}

1;
