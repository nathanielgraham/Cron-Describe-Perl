# ABSTRACT: Parser and validator for standard UNIX cron expressions
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
        Cron::Describe::DayOfMonth->new(value => $field_values[2]),  # dom
        Cron::Describe::Field->new(
            value => $field_values[3], min => 1, max => 12,
            allowed_names => { JAN => 1, FEB => 2, MAR => 3, APR => 4, MAY => 5, JUN => 6,
                               JUL => 7, AUG => 8, SEP => 9, OCT => 10, NOV => 11, DEC => 12 }
        ),  # month
        Cron::Describe::DayOfWeek->new(value => $field_values[4]),  # dow
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

    # Month-specific day limits
    my $month = $self->fields->[3]->value;
    my $dom_val = $self->fields->[2]->value;
    if ($month =~ /^(?:2|FEB)$/ && $dom_val =~ /\d+/ && $dom_val > 29) {
        $errors{range} = "Day $dom_val invalid for February";
    } elsif ($month =~ /^(?:4|6|9|11|APR|JUN|SEP|NOV)$/ && $dom_val =~ /\d+/ && $dom_val > 30) {
        $errors{range} = "Day $dom_val invalid for $month";
    }

    return (scalar keys %errors == 0, \%errors);
}

sub describe {
    my ($self) = @_;
    my @fields = @{$self->fields};
    my @names = qw(minute hour day-of-month month day-of-week);

    my @desc;
    for my $i (0..4) {
        my $val = $fields[$i]->describe($names[$i]);
        next if $val eq 'every';
        push @desc, $val;
    }

    return join(', ', @desc) || 'every minute';
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Standard - Parser and validator for standard UNIX cron expressions

=head1 DESCRIPTION

Parses, validates, and describes 5-field UNIX cron expressions (minutes, hours, day of month, month, day of week).

=head1 METHODS

=over 4

=item is_valid

Returns (boolean, \%errors) indicating if the cron expression is valid.

=item describe

Returns a concise English description of the cron expression (e.g., "at 0 minutes, from 1 to 5 days-of-month").

=back

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
