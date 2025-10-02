package Cron::Describe::DayOfMonth;

use strict;
use warnings;
use base 'Cron::Describe::Field';
use Time::Moment;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{field_type} = 'dom' unless defined $self->{field_type};
    $self->{min} = 1;
    $self->{max} = 31;
    $self->{special} = ['*', '/', '-', ',', 'L', 'W', 'LW'];
    print STDERR "DEBUG: DayOfMonth.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{field_type}\n";
    return $self;
}

sub to_english {
    my ($self, %args) = @_;
    my $pattern = $self->{pattern_type} // 'error';

    print STDERR "DEBUG: Generating to_english for DayOfMonth, pattern=$pattern\n";
    if ($pattern eq 'last') {
        my $desc = "last day-of-month" . ($self->{offset} ? " minus $self->{offset} days" : '');
        print STDERR "DEBUG: DayOfMonth last: $desc\n";
        return $desc;
    } elsif ($pattern eq 'last_weekday') {
        my $desc = "last weekday of month";
        print STDERR "DEBUG: DayOfMonth last_weekday: $desc\n";
        return $desc;
    } elsif ($pattern eq 'nearest_weekday') {
        my $desc = "nearest weekday to day $self->{day} of month";
        print STDERR "DEBUG: DayOfMonth nearest_weekday: $desc\n";
        return $desc;
    }
    my $desc = $self->SUPER::to_english(%args);
    print STDERR "DEBUG: DayOfMonth base: $desc\n";
    return $desc;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $pattern = $self->{pattern_type} // 'error';
    my $dom = $time_parts->{dom};
    my $month = $time_parts->{month};
    my $year = $time_parts->{year};

    print STDERR "DEBUG: Checking DayOfMonth match: dom=$dom, month=$month, year=$year, pattern=$pattern\n";
    return 0 if $pattern eq 'error';

    if ($pattern eq 'last') {
        my $tm = Time::Moment->new(year => $year, month => $month, day => 1, timezone => 'UTC')->plus_months(1)->minus_days(1);
        my $target = $tm->day_of_month - ($self->{offset} // 0);
        my $result = $dom == $target;
        print STDERR "DEBUG: DayOfMonth last match: target=$target, result=$result\n";
        return $result;
    } elsif ($pattern eq 'last_weekday') {
        my $tm = Time::Moment->new(year => $year, month => $month, day => 1, timezone => 'UTC')->plus_months(1)->minus_days(1);
        while ($tm->day_of_week == 0 || $tm->day_of_week == 6) {
            $tm = $tm->minus_days(1);
        }
        my $result = $dom == $tm->day_of_month;
        print STDERR "DEBUG: DayOfMonth last_weekday match: target=" . $tm->day_of_month . ", result=$result\n";
        return $result;
    } elsif ($pattern eq 'nearest_weekday') {
        my $tm = Time::Moment->new(year => $year, month => $month, day => $self->{day}, timezone => 'UTC');
        my $dow = $tm->day_of_week;
        if ($dow == 0) { # Sunday
            $tm = $tm->plus_days(1);
        } elsif ($dow == 6) { # Saturday
            $tm = $tm->minus_days(1);
        }
        my $result = $dom == $tm->day_of_month;
        print STDERR "DEBUG: DayOfMonth nearest_weekday match: target=" . $tm->day_of_month . ", result=$result\n";
        return $result;
    }
    my $result = $self->SUPER::matches($time_parts);
    print STDERR "DEBUG: DayOfMonth base match: $result\n";
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
