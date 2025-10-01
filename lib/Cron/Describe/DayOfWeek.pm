package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use base 'Cron::Describe::Field';

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    print STDERR "DEBUG: DayOfWeek.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{field_type}\n";
    return $self;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $dow = $time_parts->{dow};
    my $dom = $time_parts->{dom};
    print STDERR "DEBUG: Checking DayOfWeek match: dow=$dow, dom=$dom\n";
    if ($self->{pattern_type} eq 'nth') {
        my $occurrence = int(($dom - 1) / 7) + 1;
        if ($dow == $self->{day} && $occurrence == $self->{nth}) {
            print STDERR "DEBUG: DayOfWeek matches nth: day=$self->{day}, occurrence=$occurrence\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        my $occurrence = int(($dom - 1) / 7) + 1;
        my $dim = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
        my $max_occurrence = int(($dim - 1) / 7) + 1;
        if ($dow == $self->{day} && $occurrence == $max_occurrence) {
            print STDERR "DEBUG: DayOfWeek matches last_of_day: day=$self->{day}, occurrence=$occurrence\n";
            return 1;
        }
    } else {
        return $self->SUPER::matches($time_parts);
    }
    print STDERR "DEBUG: DayOfWeek does not match\n";
    return 0;
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english for DayOfWeek\n";
    if ($self->{pattern_type} eq 'nth') {
        my $nth = $self->{nth} == 1 ? 'first' : $self->{nth} == 2 ? 'second' : $self->{nth} == 3 ? 'third' : $self->{nth} == 4 ? 'fourth' : 'fifth';
        my $desc = "$nth $self->{day}";
        print STDERR "DEBUG: DayOfWeek nth: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        my $desc = "last $self->{day}";
        print STDERR "DEBUG: DayOfWeek last_of_day: $desc\n";
        return $desc;
    }
    my $desc = $self->SUPER::to_english();
    print STDERR "DEBUG: DayOfWeek base: $desc\n";
    return $desc;
}

1;
