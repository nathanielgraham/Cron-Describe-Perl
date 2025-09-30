# ABSTRACT: Validator for cron DayOfMonth field
package Cron::Describe::DayOfMonth;

use strict;
use warnings;
use Moo;
extends 'Cron::Describe::Field';

has 'min' => (is => 'ro', default => 1);
has 'max' => (is => 'ro', default => 31);
has 'allowed_specials' => (is => 'ro', default => sub { ['*', ',', '-', '/', '?', 'L', 'W'] });

around 'is_valid' => sub {
    my $orig = shift;
    my ($self) = @_;
    my ($valid, $errors) = $self->$orig();
    my %errors = %$errors;  # Declare %errors

    if ($self->value =~ /L/) {
        unless ($self->value =~ /^L(?:-(\d+))?$/) {
            $errors{syntax} = "Invalid L syntax: " . $self->value;
        } elsif ($1 && $1 > 31) {
            $errors{range} = "L offset $1 out of range [0-31]";
        }
    } elsif ($self->value =~ /W/) {
        unless ($self->value =~ /^(\d+)W$/) {
            $errors{syntax} = "Invalid W syntax: " . $self->value;
        } elsif ($1 < 1 || $1 > 31) {
            $errors{range} = "W value $1 out of range [1-31]";
        }
    }

    return (scalar keys %errors == 0, \%errors);
};

around 'describe' => sub {
    my $orig = shift;
    my ($self, $unit) = @_;

    my $val = $self->value;
    if ($val =~ /L/) {
        if ($val =~ /^L-(\d+)$/) {
            return "$1 day" . ($1 == 1 ? '' : 's') . " before the last day of the month";
        } elsif ($val eq 'L') {
            return "last day of the month";
        }
    } elsif ($val =~ /W/) {
        if ($val =~ /^(\d+)W$/) {
            return "nearest weekday to the $1" . ($1 == 1 ? 'st' : $1 == 2 ? 'nd' : $1 == 3 ? 'rd' : 'th');
        }
    } elsif ($val eq '?') {
        return "any day of month";
    }

    return $self->$orig('day');
};

1;

__END__

=pod

=head1 NAME

Cron::Describe::DayOfMonth - Validator for cron DayOfMonth field

=head1 DESCRIPTION

Validates and describes DayOfMonth field, including Quartz-specific L and W specials.

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
