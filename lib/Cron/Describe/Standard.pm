package Cron::Describe::Standard;

use strict;
use warnings;
use Moo;
use Carp qw(croak);
use Cron::Describe::Field;
use Cron::Describe::DayOfMonth;
use Cron::Describe::DayOfWeek;
extends 'Cron::Describe';

has 'cron_str' => (is => 'ro', required => 1);
has 'timezone' => (is => 'ro', required => 1);
has 'fields'   => (is => 'lazy', builder => '_build_fields');

sub _build_fields {
    my ($self) = @_;
    my @field_values = split /\s+/, $self->cron_str;
    croak "Standard cron requires 5 fields" unless @field_values == 5;

    return [
        Cron::Describe::Field->new(value => $field_values[0], min => 0, max => 59),  # minutes
        Cron::Describe::Field->new(value => $field_values[1], min => 0, max => 23),  # hours
        Cron::Describe::DayOfMonth->new(value => $field_values[2], min => 1, max => 31),  # dom
        Cron::Describe::Field->new(value => $field_values[3], min => 1, max => 12),  # month
        Cron::Describe::DayOfWeek->new(value => $field_values[4], min => 1, max => 7),  # dow
    ];
}

sub is_valid {
    my ($self) = @_;
    my %errors;

    foreach my $field (@{$self->fields}) {
        my ($valid, $field_errors) = $field->is_valid;
        %errors = (%errors, %$field_errors) unless $valid;
    }

    # Standard cron: both dom and dow can't be fully specified
    my ($dom, $dow) = ($self->fields->[2]->value, $self->fields->[4]->value);
    if ($dom ne '*' && $dow ne '*') {
        $errors{conflict} = "DayOfMonth and DayOfWeek cannot both be specified in standard cron";
    }

    return (scalar keys %errors == 0, \%errors);
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Standard - Parser and validator for standard UNIX cron expressions

=head1 DESCRIPTION

Parses and validates 5-field UNIX cron expressions.

=cut
