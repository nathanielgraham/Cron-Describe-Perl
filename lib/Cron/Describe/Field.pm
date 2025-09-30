package Cron::Describe::Field;

use strict;
use warnings;
use Moo;
use Carp qw(croak);

has 'value'       => (is => 'ro', required => 1);
has 'min'         => (is => 'ro', required => 1);
has 'max'         => (is => 'ro', required => 1);
has 'allowed_specials' => (is => 'ro', default => sub { [qw(* , - /)] });

sub is_valid {
    my ($self) = @_;
    my $val = $self->value;
    my %errors;

    # Validate against allowed specials
    my $specials = join '', map { quotemeta } @{$self->allowed_specials};
    my $num_regex = qr/\d+/;
    my $range_regex = qr/$num_regex-$num_regex/;
    my $list_regex = qr/$num_regex(?:,$num_regex)*/;
    my $step_regex = qr/(?:\*|$num_regex|$range_regex)\/\d+/;

    unless ($val =~ m{
        ^ (?: \* (?: / \d+ )? 
          | $range_regex (?: / \d+ )? 
          | $list_regex 
          | $num_regex
        ) $
    }x) {
        $errors{syntax} = "Invalid syntax in field: $val";
    } else {
        # Check numeric ranges
        if ($val =~ /(\d+)/) {
            my @nums = ($val =~ /(\d+)/g);
            for my $num (@nums) {
                if ($num < $self->min || $num > $self->max) {
                    $errors{range} = "Value $num out of range [$self->min-$self->max]";
                }
            }
        }
    }

    return (scalar keys %errors == 0, \%errors);
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Field - Base class for validating cron expression fields

=head1 DESCRIPTION

Handles generic field validation for cron expressions.

=head1 METHODS

=over 4

=item is_valid

Returns (boolean, \%errors) indicating if the field is valid.

=back

=cut
