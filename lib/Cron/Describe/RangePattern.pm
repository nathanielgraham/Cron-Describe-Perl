package Cron::Describe::RangePattern;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    croak "Invalid range '$value' for $field_type" unless $value =~ /^(\d+)-(\d+)$/;
    my ($start, $end) = ($1, $2);
    croak "Range start $start out of bounds for $field_type ($min-$max)" unless $start >= $min && $start <= $max;
    croak "Range end $end out of bounds for $field_type ($min-$max)" unless $end >= $min && $end <= $max;
    croak "Invalid range: start $start greater than end $end for $field_type" unless $start <= $end;
    my $self = bless {}, $class;
    $self->{start_value} = $start;
    $self->{end_value} = $end;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return $value >= $self->{start_value} && $value <= $self->{end_value};
}

sub to_hash {
    my $self = shift;
    return {
        field_type => $self->{field_type},
        pattern_type => 'range',
        start_value => $self->{start_value},
        end_value => $self->{end_value},
        min => $self->{min},
        max => $self->{max},
        step => 1
    };
}

1;
