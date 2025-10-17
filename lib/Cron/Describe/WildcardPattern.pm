package Cron::Describe::WildcardPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';
use Cron::Describe::Utils qw(:all);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'wildcard';
    croak "Invalid wildcard pattern '$value' for $field_type" unless $value eq '*';
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return $value >= $self->{min} && $value <= $self->{max};
}

sub to_english {
    my ($self) = @_;
    return "any $self->{field_type}";
}

sub to_string {
    my ($self) = @_;
    return '*';
}

sub to_hash {
    my ($self) = @_;
    return $self->SUPER::to_hash;
}

1;
