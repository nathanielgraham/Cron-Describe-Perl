package Cron::Describe::SinglePattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'single';
    unless ($value =~ /^\d+$/ && $value >= $min && $value <= $max) {
        $self->add_error("Invalid value '$value' for $field_type, expected $min-$max");
        croak $self->errors->[0];
    }
    $self->validate();
    return $self;
}

sub validate {
    my ($self) = @_;
    unless ($self->{value} =~ /^\d+$/ && $self->{value} >= $self->{min} && $self->{value} <= $self->{max}) {
        $self->add_error("Invalid value '$self->{value}' for $self->{field_type}, expected $self->{min}-$self->{max}");
        croak $self->errors->[0];
    }
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $result = $value == $self->{value};
    $self->_debug("is_match: value=$value, expected=$self->{value}, result=$result");
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    $hash->{value} = $self->{value};
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return $self->{value};
}

sub to_english {
    my ($self) = @_;
    return "exactly $self->{value}";
}

1;
