package Cron::Describe::DayOfWeekPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';
use Time::Moment;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: DayOfWeekPattern::new: value='$value', field_type='$field_type'\n" if $Cron::Describe::DEBUG;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'unspecified';
    my $days = { 0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday' };
    if (defined $value && $value eq '?') {
        $self->{pattern_type} = 'unspecified';
    } elsif ($value =~ /^([0-7])#([0-9])$/) {
        my ($day, $nth) = ($1, $2);
        $self->{pattern_type} = 'nth';
        $self->{day} = $day;
        $self->{nth} = $nth;
        $self->{is_special} = 1;
        if ($nth > 5) {
            my $day_name = $days->{$day} || 'unknown';
            $self->add_error("Sixth $day_name is impossible in any month");
            croak $self->errors->[0];
        }
    } elsif ($value =~ /^[0-7]L$/) {
        $self->{pattern_type} = 'last_of_day';
        $self->{day} = substr($value, 0, 1);
        $self->{is_special} = 1;
    } elsif ($value =~ /^[0-7](,[0-7])*$/) {
        $self->{pattern_type} = 'list';
        $self->{sub_patterns} = [ map { Cron::Describe::SinglePattern->new($_, $min, $max, $field_type) } split /,/, $value ];
        $self->{is_special} = 1;
    } else {
        $self->add_error("Invalid day-of-week pattern '$value' for $field_type");
        croak $self->errors->[0];
    }
    $self->validate();
    print STDERR "DEBUG: DayOfWeekPattern: pattern_type=$self->{pattern_type}, day=" . ($self->{day} // 'undef') . ", nth=" . ($self->{nth} // 'undef') . "\n" if $Cron::Describe::DEBUG;
    return $self;
}

sub validate {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'unspecified') {
        unless (defined $self->{value} && $self->{value} eq '?') {
            $self->add_error("Invalid unspecified pattern '" . ($self->{value} // 'undef') . "' for $self->{field_type}, expected '?'");
        }
    } elsif ($self->{pattern_type} eq 'list') {
        if (defined $self->{sub_patterns}) {
            foreach my $pattern (@{$self->{sub_patterns}}) {
                $pattern->validate();
            }
        } else {
            $self->add_error("No sub-patterns defined for list pattern in $self->{field_type}");
        }
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        unless (defined $self->{day} && $self->{value} =~ /^[0-7]L$/) {
            $self->add_error("Invalid last-of-day pattern '" . ($self->{value} // 'undef') . "' for $self->{field_type}");
        }
    }
    croak join("; ", @{$self->errors}) if $self->has_errors;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $result = 0;
    my $target_day;
    if ($self->{pattern_type} eq 'unspecified') {
        $result = 1;
    } elsif ($self->{pattern_type} eq 'list') {
        $result = grep { $_->is_match($value, $tm) } @{$self->{sub_patterns}};
        $target_day = join(",", map { $_->to_string } @{$self->{sub_patterns}});
    } elsif ($self->{pattern_type} eq 'nth') {
        my $day = $self->{day};
        my $nth = $self->{nth};
        my $month = $tm->month;
        my $year = $tm->year;
        my $max_days = $tm->length_of_month;
        my $first_day = Time::Moment->new(year => $year, month => $month, day => 1)->day_of_week % 7;
        my $offset = ($day - $first_day) % 7;
        $offset += 7 if $offset < 0;
        $target_day = $offset + 1 + ($nth - 1) * 7;
        if ($target_day <= $max_days) {
            $result = $tm->day_of_month == $target_day && $value == $day;
        }
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        my $day = $self->{day};
        my $month = $tm->month;
        my $year = $tm->year;
        my $last_day = $tm->length_of_month;
        my $last_day_moment = Time::Moment->new(year => $year, month => $month, day => $last_day);
        my $last_day_dow = $last_day_moment->day_of_week % 7;
        $target_day = $last_day;
        if ($last_day_dow != $day) {
            my $offset = ($last_day_dow - $day) % 7;
            $offset += 7 if $offset < 0;
            $target_day = $last_day - $offset;
        }
        $result = $tm->day_of_month == $target_day && $value == $day;
    }
    $self->_debug("is_match: pattern_type=$self->{pattern_type}, value=$value, target_day=" . ($target_day // 'undef') . ", dow=" . ($tm->day_of_week % 7) . ", result=$result");
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    $hash->{is_special} = 1 if $self->{pattern_type} eq 'nth' || $self->{pattern_type} eq 'last_of_day' || $self->{pattern_type} eq 'list';
    $hash->{day} = $self->{day} if defined $self->{day};
    $hash->{nth} = $self->{nth} if defined $self->{nth};
    $hash->{sub_patterns} = [ map { $_->to_hash } @{$self->{sub_patterns}} ] if $self->{sub_patterns};
    print STDERR "DEBUG: DayOfWeekPattern::to_hash: " . join(", ", map { "$_=$hash->{$_}" } keys %$hash) . "\n" if $Cron::Describe::DEBUG;
    return $hash;
}

sub to_string {
    my ($self) = @_;
    if ($self->{pattern_type} eq 'unspecified') {
        return '?';
    } elsif ($self->{pattern_type} eq 'list') {
        return join(',', map { $_->to_string } @{$self->{sub_patterns}});
    } elsif ($self->{pattern_type} eq 'nth') {
        return "$self->{day}#$self->{nth}";
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        return "$self->{day}L";
    }
    return '';
}

sub to_english {
    my ($self) = @_;
    my $days = { 0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday' };
    if ($self->{pattern_type} eq 'unspecified') {
        return "any";
    } elsif ($self->{pattern_type} eq 'list') {
        return join(" or ", map { $_->to_english } @{$self->{sub_patterns}});
    } elsif ($self->{pattern_type} eq 'nth') {
        my $ordinals = { 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', 5 => 'fifth' };
        return "$ordinals->{$self->{nth}} $days->{$self->{day}}";
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        return "last $days->{$self->{day}}";
    }
    return "";
}

1;
