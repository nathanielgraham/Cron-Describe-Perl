# File: lib/Cron/Describe/DayOfMonthPattern.pm
package Cron::Describe::DayOfMonthPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';
use DateTime;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = bless {
        pattern_type => 'special',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        field_type => $field_type,
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
            push @{$self->{errors}}, "Invalid pattern: $value is not a valid day-of-month pattern";
        } else {
            %$self = (%$self, %$pattern, field_type => 'dom');
        }
    }
    return $self;
}

sub _parse_special {
    my ($self, $value) = @_;
    if ($value eq 'L') {
        return { pattern_type => 'last', offset => 0 };
    } elsif ($value eq 'LW') {
        return { pattern_type => 'last_weekday', offset => 0 };
    } elsif ($value =~ /^L-(\d+)$/) {
        my $offset = $1 + 0;
        if ($offset >= 0 && $offset <= 30) {
            return { pattern_type => 'last', offset => $offset };
        }
    } elsif ($value =~ /^(\d+)W$/) {
        my $day = $1 + 0;
        if ($day >= 1 && $day <= 31) {
            return { pattern_type => 'nearest_weekday', day => $day };
        }
    }
    return undef;
}

sub validate {
    my ($self) = @_;
    return 0 if $self->has_errors;
    return 1 if $self->{pattern_type} =~ /^(last|last_weekday|nearest_weekday)$/;
    return $self->SUPER::validate();
}

sub is_match {
    my ($self, $value) = @_;
    return 0 if $self->has_errors;

    if ($self->{pattern_type} eq 'last') {
        my $date = Time::Moment->now->with_day_of_month($value);
        my $last_day = $date->length_of_month;
        my $target_day = $last_day - ($self->{offset} // 0);
        return $value == $target_day && $target_day >= 1;
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        my $date = Time::Moment->now->with_day_of_month($value);
        my $last_day = $date->length_of_month;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $last_day,
            time_zone => 'UTC'
        );
        while ($dt->day_of_week == 0 || $dt->day_of_week == 6) {
            $dt->subtract(days => 1);
        }
        return $value == $dt->day;
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        my $target_day = $self->{day} // 0;
        my $date = Time::Moment->now->with_day_of_month($value);
        my $last_day = $date->length_of_month;
        return 0 if $target_day > $last_day;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $target_day,
            time_zone => 'UTC'
        );
        my $dow = $dt->day_of_week;
        if ($dow == 0 || $dow == 6) {
            my $offset = $dow == 6 ? -1 : 1;
            $dt->add(days => $offset);
            while ($dt->day > $last_day || $dt->day_of_week == 0 || $dt->day_of_week == 6) {
                $dt->add(days => $offset > 0 ? -1 : 1);
            }
        }
        return $value == $dt->day;
    }
    return $self->SUPER::is_match($value);
}

sub to_english {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'last') {
        return ($self->{offset} // 0) ? "on $self->{offset} days before the last day of month" : "on last day of month";
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        return "on last weekday of month";
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        return "on nearest weekday to day $self->{day} of month";
    }
    my $desc = $self->SUPER::to_english();
    return $desc =~ /invalid/ ? "every day of month" : ($desc =~ /^on / ? $desc : "on $desc of month");
}

sub to_string {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'last') {
        return ($self->{offset} // 0) ? "L-$self->{offset}" : "L";
    } elsif ($self->{pattern_type} eq 'last_weekday') {
        return "LW";
    } elsif ($self->{pattern_type} eq 'nearest_weekday') {
        return "$self->{day}W";
    }
    return $self->SUPER::to_string();
}

1;
