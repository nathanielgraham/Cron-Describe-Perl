# ABSTRACT: Parser and validator for Quartz Scheduler cron expressions
package Cron::Describe::Quartz;

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
    my $count = @field_values;
    croak "Quartz cron requires 6-7 fields" unless $count == 6 || $count == 7;

    my @fields = (
        Cron::Describe::Field->new(value => $field_values[0], min => 0, max => 59),  # seconds
        Cron::Describe::Field->new(value => $field_values[1], min => 0, max => 59),  # minutes
        Cron::Describe::Field->new(value => $field_values[2], min => 0, max => 23),  # hours
        Cron::Describe::DayOfMonth->new(value => $field_values[3]),  # dom
        Cron::Describe::Field->new(
            value => $field_values[4], min => 1, max => 12,
            allowed_names => { JAN => 1, FEB => 2, MAR => 3, APR => 4, MAY => 5, JUN => 6,
                               JUL => 7, AUG => 8, SEP => 9, OCT => 10, NOV => 11, DEC => 12 }
        ),  # month
        Cron::Describe::DayOfWeek->new(value => $field_values[5]),  # dow
    );
    push @fields, Cron::Describe::Field->new(value => $field_values[6], min => 1970, max => 2099) if $count == 7;  # year

    return \@fields;
}

sub is_valid {
    my ($self) = @_;
    my %errors;

    foreach my $field (@{$self->fields}) {
        my ($valid, $field_errors) = $field->is_valid;
        %errors = (%errors, %$field_errors) unless $valid;
    }

    # Quartz: either dom or dow must be ?
    my ($dom, $dow) = ($self->fields->[3]->value, $self->fields->[5]->value);
    if ($dom ne '?' && $dow ne '?') {
        $errors{conflict} = "Either DayOfMonth or DayOfWeek must be ? in Quartz cron";
    }

    # Month-specific day limits
    my $month = $self->fields->[4]->value;
    my $dom_val = $self->fields->[3]->value;
    if ($month =~ /^(?:2|FEB)$/ && $dom_val =~ /\d+/ && $dom_val > 29) {
        $errors{range} = "Day $dom_val invalid for February";
    } elsif ($month =~ /^(?:4|6|9|11|APR|JUN|SEP|NOV)$/ && $dom_val =~ /\d+/ && $dom_val > 30) {
        $errors{range} = "Day $dom_val invalid for $month";
    }

    # Check for impossible nth day (e.g., 5th Monday in Feb)
    if ($dow =~ /#5/ && $month =~ /^(?:2|FEB)$/) {
        $errors{impossible} = "Invalid: Fifth weekday in February is impossible";
    }

    return (scalar keys %errors == 0, \%errors);
}

sub describe {
    my ($self) = @_;
    my @fields = @{$self->fields};
    my @names = qw(second minute hour day-of-month month day-of-week year);

    my @desc;
    for my $i (0..$#fields) {
        my $val = $fields[$i]->describe($names[$i]);
        next if $val eq 'every';
        push @desc, $val;
    }

    return join(', ', @desc) || 'every second';
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Quartz - Parser and validator for Quartz Scheduler cron expressions

=head1 DESCRIPTION

Parses, validates, and describes 6-7 field Quartz cron expressions (seconds, minutes, hours, day of month, month, day of week, optional year).

=head1 METHODS

=over 4

=item is_valid

Returns (boolean, \%errors) indicating if the cron expression is valid.

=item describe

Returns a concise English description of the cron expression (e.g., "every 5 seconds, at 12 hours, any day of month").

=back

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
