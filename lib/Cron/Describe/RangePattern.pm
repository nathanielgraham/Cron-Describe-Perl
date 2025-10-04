# File: lib/Cron/Describe/RangePattern.pm
package Cron::Describe::RangePattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = bless {
        pattern_type => 'range',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        field_type   => $field_type,
        errors => [],
    }, $class;

    if ($value =~ m{^(\d+)-(\d+)$}) {
        my ($start, $end) = ($1 + 0, $2 + 0);
        if ($start <= $end && $start >= $min && $end <= $max) {
            $self->{min} = $start;
            $self->{max} = $end;
            $self->{min_value} = $start;
            $self->{max_value} = $end;
        } else {
            push @{$self->{errors}}, "Invalid range $start-$end: out of bounds [$min-$max] or start > end";
        }
    } else {
        push @{$self->{errors}}, "Invalid range pattern: $value";
    }
    return $self;
}

sub validate {
    my ($self) = @_;
    return ! $self->has_errors;
}

sub is_match {
    my ($self, $value) = @_;
    return $value >= $self->{min} && $value <= $self->{max};
}

sub to_english {
    my ($self) = @_;
    return "from $self->{min} to $self->{max} $self->{field_type}";
}

sub to_string {
    my ($self) = @_;
    return "$self->{min}-$self->{max}";
}

1;
