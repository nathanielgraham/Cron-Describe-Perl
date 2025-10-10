package Cron::Describe::UnspecifiedPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'unspecified';
    $self->validate();
    print STDERR "DEBUG: UnspecifiedPattern: Initialized $class with value='$value', field_type='$field_type', min=$min, max=$max\n" if $Cron::Describe::DEBUG;
    return $self;
}

sub validate {
    my ($self) = @_;
    unless ($self->{value} eq '?') {
        $self->add_error("Invalid unspecified '$self->{value}' for $self->{field_type}, expected '?'");
        croak $self->errors->[0];
    }
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $result = 1; # Unspecified matches all values
    $self->_debug("is_match: value=$value, result=$result");
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return '?';
}

sub to_english {
    my ($self) = @_;
    return "any";
}

1;
