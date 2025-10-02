package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use base 'Cron::Describe::Field';
use Time::Moment;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    print STDERR "DEBUG: DayOfWeek.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{field_type}\n";
    return $self;
}

sub to_english {
    my ($self, %args) = @_;
    my $pattern = $self->{pattern_type} // 'error';
    my %days = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');

    print STDERR "DEBUG: Generating to_english for DayOfWeek, pattern=$pattern\n";
    if ($pattern eq 'nth') {
        my $nth = $self->{nth} == 1 ? 'first' : $self->{nth} == 2 ? 'second' : $self->{nth} == 3 ? 'third' : $self->{nth} == 4 ? 'fourth' : 'fifth';
        my $desc = "$nth $days{$self->{day}}";
        print STDERR "DEBUG: DayOfWeek nth: $desc\n";
        return $desc;
    } elsif ($pattern eq 'last_of_day') {
        my $desc = "last $days{$self->{day}}";
        print STDERR "DEBUG: DayOfWeek last_of_day: $desc\n";
        return $desc;
    }
    my $desc = $self->SUPER::to_english(%args);
    print STDERR "DEBUG: DayOfWeek base: $desc\n";
    return $desc;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $pattern = $self->{pattern_type} // 'error';
    my $dow = $time_parts->{dow};
    my $dom = $time_parts->{dom};
    my $month = $time_parts->{month};
    my $year = $time_parts->{year};

    print STDERR "DEBUG: Checking DayOfWeek match: dow=$dow, dom=$dom, month=$month, year=$year, pattern=$pattern\n";
    return 0 if $pattern eq 'error';

    if ($pattern eq 'nth') {
        my $tm = Time::Moment->new(year => $year, month => $month, day => 1, timezone => 'UTC');
        my $count = 0;
        my $target_day = $self->{day};
        while ($tm->month == $month) {
            if ($tm->day_of_week - 1 == $target_day) {
                $count++;
                if ($count == $self->{nth} && $tm->day_of_month == $dom) {
                    print STDERR "DEBUG: DayOfWeek nth match: day=$target_day, occurrence=$count, dom=$dom\n";
                    return 1;
                }
            }
            $tm = $tm->plus_days(1);
        }
        print STDERR "DEBUG: DayOfWeek nth does not match\n";
        return 0;
    } elsif ($pattern eq 'last_of_day') {
        my $tm = Time::Moment->new(year => $year, month => $month, day => 1, timezone => 'UTC')->plus_months(1)->minus_days(1);
        while ($tm->month == $month) {
            if ($tm->day_of_week - 1 == $self->{day} && $tm->day_of_month == $dom) {
                print STDERR "DEBUG: DayOfWeek last_of_day match: day=$self->{day}, dom=$dom\n";
                return 1;
            }
            $tm = $tm->minus_days(1);
        }
        print STDERR "DEBUG: DayOfWeek last_of_day does not match\n";
        return 0;
    }
    my $result = $self->SUPER::matches($time_parts);
    print STDERR "DEBUG: DayOfWeek base match: $result\n";
    return $result;
}

sub _days_in_month {
    my ($self, $month, $year) = @_;
    my $tm = Time::Moment->new(year => $year // 2025, month => $month, day => 1, timezone => 'UTC')->plus_months(1)->minus_days(1);
    my $d = $tm->day_of_month;
    print STDERR "DEBUG: Days in month $month (year=$year): $d\n";
    return $d;
}

1;
