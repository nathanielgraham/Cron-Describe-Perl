# ABSTRACT: Validator for cron DayOfMonth field
package Cron::Describe::DayOfMonth;

use strict;
use warnings;
use Moo;
extends 'Cron::Describe::Field';

has '+min' => (default => 1);
has '+max' => (default => 31);
has '+allowed_specials' => (default => sub { ['*', ',', '-', '/', '?', 'L', 'W'] });

around 'is_valid' => sub {
    my $orig = shift;
    my ($self) = @_;
    my ($valid, $errors) = $self->$orig();
    my %errors = %$errors;  # Declare %errors

    if ($self->value =~ /L/) {
        unless ($self->value =~ /^L(?:-\d+)?$/) {
            $errors{syntax} = "Invalid L syntax: " . $self->value;
        }
    } elsif ($self->value =~ /W/) {
        unless ($self->value =~ /^\d+W$/) {
            $errors{syntax} = "Invalid W syntax: " . $self->value;
        }
    }

    return (scalar keys %errors == 0, \%errors);
};

1;

__END__

=pod

=head1 NAME

Cron::Describe::DayOfMonth - Validator for cron DayOfMonth field

=head1 DESCRIPTION

Validates DayOfMonth field, including Quartz-specific L and W specials.

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
