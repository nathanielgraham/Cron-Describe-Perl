# ABSTRACT: Validator for cron DayOfWeek field
package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use Moo;
extends 'Cron::Describe::Field';

has 'min' => (is => 'ro', default => 1);
has 'max' => (is => 'ro', default => 7);
has 'allowed_specials' => (is => 'ro', default => sub { ['*', ',', '-', '/', '?', 'L', '#'] });

my %names = (SUN => 1, MON => 2, TUE => 3, WED => 4, THU => 5, FRI => 6, SAT => 7);

around 'is_valid' => sub {
    my $orig = shift;
    my ($self) = @_;
    my ($valid, $errors) = $self->$orig();
    my %errors = %$errors;  # Declare %errors

    if ($self->value =~ /[A-Z]{3}/i) {
        my $name = uc($self->value);
        unless (exists $names{$name}) {
            $errors{syntax} = "Invalid day name: $name";
        }
    } elsif ($self->value =~ /#/) {
        unless ($self->value =~ /^(\d+|SUN|MON|TUE|WED|THU|FRI|SAT)#([1-5])$/) {
            $errors{syntax} = "Invalid # syntax: " . $self->value;
        }
    }

    return (scalar keys %errors == 0, \%errors);
};

1;

__END__

=pod

=head1 NAME

Cron::Describe::DayOfWeek - Validator for cron DayOfWeek field

=head1 DESCRIPTION

Validates DayOfWeek field, including Quartz-specific # and day names (e.g., MON).

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
