package Cron::Describe::RangePattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'range';
    if ($value =~ /^(\d+)-(\d+)$/) {
        $self->{start_value} = $1;
        $self->{end_value} = $2;
        croak "Invalid range '$value' for $field_type: start ($1) must be <= end ($2)" unless $1 <= $2;
        croak "Invalid range '$value' for $field_type: start ($1) must be >= $min" unless $1 >= $min;
        croak "Invalid range '$value' for $field_type: end ($2) must be <= $max" unless $2 <= $max;
    } else {
        croak "Invalid range pattern '$value' for $field_type";
    }
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return $value >= $self->{start_value} && $value <= $self->{end_value};
}

sub to_english {
    my ($self) = @_;
    return "from $self->{start_value} to $self->{end_value}";
}

sub to_string {
    my ($self) = @_;
    return "$self->{start_value}-$self->{end_value}";
}

sub to_hash {
    my ($self) = @_;
    my $hash = $self->SUPER::to_hash;
    $hash->{start_value} = $self->{start_value};
    $hash->{end_value} = $self->{end_value};
    return $hash;
}

1;
