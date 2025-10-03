package Cron::Describe::DayOfWeek;
use strict;
use warnings;
use parent 'Cron::Describe::Field';
use Time::Moment;

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    print STDERR "DEBUG: DayOfWeek.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $args{field_type}\n";
    return $self;
}

sub to_english {
    my ($self, %args) = @_;
    my $pattern = $self->{pattern_type};
    my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday', 7 => 'Sunday');
    if ($pattern eq 'nth') {
        my $nth = $self->{nth};
        my $day = $dow_names{$self->{day}};
        my @ordinals = qw(first second third fourth fifth);
        return "$ordinals[$nth-1] $day";
    } elsif ($pattern eq 'last_of_day') {
        my $day = $dow_names{$self->{day}};
        return "last $day of month";
    }
    return $self->SUPER::to_english(%args);
}

sub matches {
    my ($self, $time_parts) = @_;
    my $pattern = $self->{pattern_type};
    my $val = $time_parts->{dow};
    my $month = $time_parts->{month};
    my $year = $time_parts->{year} // 2025;
    my $dom = $time_parts->{dom};
    print STDERR "DEBUG: Matching DOW value $val against pattern $pattern (month=$month, year=$year, dom=$dom)\n" if $self->{parent}{debug};
    if ($pattern eq 'nth') {
        my $target_day = $self->{day};
        my $target_nth = $self->{nth};
        # Find all occurrences of target_day in the month
        my $tm = Time::Moment->new(year => $year, month => $month, day => 1);
        my $days_in_month = $self->{parent}->_days_in_month($month, $year);
        my $count = 0;
        for my $day (1..$days_in_month) {
            my $current_tm = Time::Moment->new(year => $year, month => $month, day => $day);
            my $dow = $current_tm->day_of_week; # 1=Mon, 7=Sun
            my $quartz_dow = $dow == 7 ? 0 : $dow; # Convert to Quartz: 7=Sun -> 0, 1=Mon -> 1, etc.
            if ($quartz_dow == $target_day) {
                $count++;
                if ($count == $target_nth && $day == $dom) {
                    return 1;
                }
            }
        }
        return 0;
    } elsif ($pattern eq 'last_of_day') {
        my $target_day = $self->{day};
        my $days_in_month = $self->{parent}->_days_in_month($month, $year);
        my $tm = Time::Moment->new(year => $year, month => $month, day => $days_in_month);
        # Find last occurrence of target_day
        while ($tm->day_of_week != ($target_day == 0 ? 7 : $target_day)) { # Quartz 0=Sun -> TM 7, 1=Mon -> TM 1
            $tm = $tm->minus_days(1);
        }
        return $dom == $tm->day_of_month;
    }
    return $self->SUPER::matches($time_parts);
}

1;
