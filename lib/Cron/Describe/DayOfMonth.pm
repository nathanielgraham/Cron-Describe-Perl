package Cron::Describe::DayOfMonth;
use strict;
use warnings;
use base 'Cron::Describe::Field';

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    print STDERR "DEBUG: DayOfMonth.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{field_type}\n";
    return $self;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $dom = $time_parts->{dom};
    print STDERR "DEBUG: Checking DayOfMonth match: dom=$dom\n";
    if ($self->{pattern_type} eq 'last') {
        my $last_day = $self->_days_in_month($time_parts->{month}, $time_parts->{year});
        if ($dom == $last_day - $self->{offset}) {
            print STDERR "DEBUG: DayOfMonth matches last: dom=$dom, last_day=$last_day, offset=$self->{offset}\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $last_day = $self->_days_in_month($time_parts->{month}, $time_parts->{year});
        my $dow = $self->_dow_of_date($time_parts->{year}, $time_parts->{month}, $last_day);
        my $target_day = $last_day;
        if ($dow == 6) { $target_day -= 1; } # Sat -> Fri
        elsif ($dow == 0) { $target_day -= 2; } # Sun -> Fri
        if ($dom == $target_day) {
            print STDERR "DEBUG: DayOfMonth matches last_weekday: dom=$dom, target_day=$target_day\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $target_day = $self->{day};
        my $dow = $self->_dow_of_date($time_parts->{year}, $time_parts->{month}, $target_day);
        if ($dow == 6) { $target_day -= 1; } # Sat -> Fri
        elsif ($dow == 0) { $target_day += 1; } # Sun -> Mon
        my $dim = $self->_days_in_month($time_parts->{month}, $time_parts->{year});
        if ($target_day < 1 || $target_day > $dim) {
            print STDERR "DEBUG: DayOfMonth does not match nearest_weekday: target_day=$target_day out of bounds\n";
            return 0;
        }
        if ($dom == $target_day) {
            print STDERR "DEBUG: DayOfMonth matches nearest_weekday: dom=$dom, target_day=$target_day\n";
            return 1;
        }
    } else {
        return $self->SUPER::matches($time_parts);
    }
    print STDERR "DEBUG: DayOfMonth does not match\n";
    return 0;
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english for DayOfMonth\n";
    if ($self->{pattern_type} eq 'last') {
        my $desc = $self->{offset} ? "last day minus $self->{offset}" : "last day";
        print STDERR "DEBUG: DayOfMonth last: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $desc = "last weekday";
        print STDERR "DEBUG: DayOfMonth last_weekday: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $desc = "nearest weekday to the $self->{day}";
        print STDERR "DEBUG: DayOfMonth nearest_weekday: $desc\n";
        return $desc;
    }
    my $desc = $self->SUPER::to_english();
    print STDERR "DEBUG: DayOfMonth base: $desc\n";
    return $desc;
}

sub _days_in_month {
    my ($self, $mon, $year) = @_;
    my $d = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)[$mon];
    $d = 29 if $mon == 2 && $year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0);
    return $d;
}

sub _dow_of_date {
    my ($self, $year, $mon, $dom) = @_;
    my $dt = DateTime->new(year => $year, month => $mon, day => $dom, time_zone => $self->{time_zone});
    return $dt->day_of_week % 7; # Convert 1-7 to 0-6
}

1;
