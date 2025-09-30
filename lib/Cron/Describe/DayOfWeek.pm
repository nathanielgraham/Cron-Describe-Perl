# ABSTRACT: Validator for cron DayOfWeek field
package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use Moo;
extends 'Cron::Describe::Field';

has 'min' => (is => 'ro', default => 1);
has 'max' => (is => 'ro', default => 7);
has 'allowed_specials' => (is => 'ro', default => sub { ['*', ',', '-', '/', '?', 'L', '#'] });
has 'allowed_names' => (is => 'ro', default => sub { {
    SUN => 1, MON => 2, TUE => 3, WED => 4, THU => 5, FRI => 6, SAT => 7
} });

around 'is_valid' => sub {
    my $orig = shift;
    my ($self) = @_;
    my ($valid, $errors) = $self->$orig();
    my %errors = %$errors;  # Declare %errors

    if ($self->value =~ /#/) {
        unless ($self->value =~ /^(?:\d+|SUN|MON|TUE|WED|THU|FRI|SAT)#([1-5])$/) {
            $errors{syntax} = "Invalid # syntax: " . $self->value;
        } elsif ($self->value =~ /^(\d+)#/) {
            my $num = $1;
            if ($num < 1 || $num > 7) {
                $errors{range} = "Day number $num out of range [1-7]";
            }
        }
    }

    return (scalar keys %errors == 0, \%errors);
};

around 'describe' => sub {
    my $orig = shift;
    my ($self, $unit) = @_;

    my $val = $self->value;
    if ($val =~ /#/) {
        if ($val =~ /^(\w+)#(\d+)$/) {
            my ($day, $nth) = ($1, $2);
            return "the $nth" . ($nth == 1 ? "st" : $nth == 2 ? "nd" : $nth == 3 ? "rd" : "th") . " " . lc($day) . " day";
        }
    } elsif ($val eq '?') {
        return "any day of week";
    } elsif ($val eq 'L') {
        return "last Saturday";
    } elsif ($self->allowed_names->{$val}) {
        return lc($val) . " day";
    }

    return $self->$orig('day');
};

1;

__END__

=pod

=head1 NAME

Cron::Describe::DayOfWeek - Validator for cron DayOfWeek field

=head1 DESCRIPTION

Validates and describes DayOfWeek field, including Quartz-specific # and day names (e.g., MON).

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
