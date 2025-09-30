package Cron::Describe::DayOfMonth;

use strict;
use warnings;
use Moo;
extends 'Cron::Describe::Field';

has '+min' => (default => 1);
has '+max' => (default => 31);
has '+allowed_specials' => (default => sub { [qw(* , - / ? L W)] });

around 'is_valid' => sub {
    my $orig = shift;
    my ($self) = @_;
    my ($valid, $errors) = $self->$orig();

    if ($self->value =~ /L/) {
        unless ($self->value =~ /^L(?:-\d+)?$/) {
            $errors->{syntax} = "Invalid L syntax: " . $self->value;
        }
    } elsif ($self->value =~ /W/) {
        unless ($self->value =~ /^\d+W$/) {
            $errors->{syntax} = "Invalid W syntax: " . $self->value;
        }
    }

    return (scalar keys %errors == 0, $errors);
};

1;

__END__

=pod

=head1 NAME

Cron::Describe::DayOfMonth - Validator for cron DayOfMonth field

=head1 DESCRIPTION

Validates DayOfMonth field, including Quartz-specific L and W.

=cut
