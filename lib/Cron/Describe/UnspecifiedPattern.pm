package Cron::Describe::UnspecifiedPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'unspecified';
    croak "Invalid unspecified pattern '$value' for $field_type" unless $value eq '?';
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return 1;
}

sub to_english {
    my ($self) = @_;
    return "any $self->{field_type}";
}

sub to_string {
    my ($self) = @_;
    return '?';
}

sub to_hash {
    my ($self) = @_;
    return $self->SUPER::to_hash;
}

1;
