package Cron::Describe::RangePattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'range';
    unless ($value =~ /^(\d+)-(\d+)$/) {
        $self->add_error("Invalid range '$value' for $field_type");
        croak $self->errors->[0];
    }
    $self->{start_value} = $1;
    $self->{end_value} = $2;
    $self->validate();
    return $self;
}

sub validate {
    my ($self) = @_;
    if ($self->{start_value} < $self->{min} || $self->{start_value} > $self->{max}) {
        $self->add_error("Range start $self->{start_value} out of bounds for $self->{field_type} ($self->{min}-$self->{max})");
    }
    if ($self->{end_value} < $self->{min} || $self->{end_value} > $self->{max}) {
        $self->add_error("Range end $self->{end_value} out of bounds for $self->{field_type} ($self->{min}-$self->{max})");
    }
    if ($self->{start_value} > $self->{end_value}) {
        $self->add_error("Invalid range: start $self->{start_value} greater than end $self->{end_value} for $self->{field_type}");
    }
    croak join("; ", @{$self->errors}) if $self->has_errors;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $result = $value >= $self->{start_value} && $value <= $self->{end_value};
    $self->_debug("is_match: value=$value, start=$self->{start_value}, end=$self->{end_value}, result=$result");
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    $hash->{start_value} = $self->{start_value};
    $hash->{end_value} = $self->{end_value};
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return "$self->{start_value}-$self->{end_value}";
}

sub to_english {
    my ($self) = @_;
    return "from $self->{start_value} to $self->{end_value}";
}

1;
