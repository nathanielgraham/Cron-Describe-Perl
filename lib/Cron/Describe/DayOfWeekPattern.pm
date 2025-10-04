# File: lib/Cron/Describe/DayOfWeekPattern.pm
package Cron::Describe::DayOfWeekPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max) = @_;
    my $self = bless {
        pattern_type => 'special',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        field_type => 'dow',
        errors => [],
    }, $class;

    my $special = $self->_parse_special($value);
    if ($special) {
        %$self = (%$self, %$special);
    } else {
        my $pattern = $self->SUPER::new($value, $min, $max);
        if ($pattern->has_errors) {
            push @{$self->{errors}}, @{ $pattern->{errors} };
        } elsif (ref($pattern) eq 'Cron::Describe::Pattern') {
            push @{$self->{errors}}, "Invalid pattern: $value is not a valid day-of-week pattern";
        } else {
            %$self = (%$self, %$pattern, field_type => 'dow');
        }
    }
    return $self;
}

sub _parse_special {
    my ($self, $value) = @_;
    if ($value =~ /^(\d+)#(\d+)$/) {
        my ($day, $nth) = ($1 + 0, $2 + 0);
        if ($day >= 0 && $day <= 7 && $nth >= 1 && $nth <= 5) {
            return { pattern_type => 'nth', day => $day, nth => $nth };
        }
    } elsif ($value =~ /^(\d+)L$/) {
        my $day = $1 + 0;
        if ($day >= 0 && $day <= 7) {
            return { pattern_type => 'last_of_day', day => $day };
        }
    }
    return undef;
}

sub validate {
    my ($self) = @_;
    return 0 if $self->has_errors;
    return 1 if $self->{pattern_type} =~ /^(nth|last_of_day)$/;
    return $self->SUPER::validate();
}

sub is_match {
    my ($self, $value) = @_;
    return 0 if $self->has_errors;

    if ($self->{pattern_type} eq 'nth') {
        my $date = Time::Moment->now->with_day_of_week($value % 7);
        my $week = int(($date->day_of_month - 1) / 7) + 1;
        return $value == $self->{day} && $week == $self->{nth};
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        my $date = Time::Moment->now->with_day_of_week($value % 7);
        my $last_day = $date->length_of_month;
        my $week = int(($last_day - $date->day_of_month) / 7) + 1;
        return $value == $self->{day} && $week == 1;
    }
    return $self->SUPER::is_match($value);
}

sub to_english {
    my ($self) = @_;
    my %days = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday');
    if ($self->{pattern_type} eq 'nth') {
        my $nth = $self->{nth} == 1 ? 'first' : $self->{nth} == 2 ? 'second' : $self->{nth} == 3 ? 'third' : $self->{nth} == 4 ? 'fourth' : 'fifth';
        return "on the $nth $days{$self->{day}}";
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        return "on the last $days{$self->{day}}";
    }
    my $desc = $self->SUPER::to_english();
    return $desc =~ /invalid/ ? "every day-of-week" : $desc;
}

sub to_string {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'nth') {
        return "$self->{day}#$self->{nth}";
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        return "$self->{day}L";
    }
    return $self->SUPER::to_string();
}

1;
