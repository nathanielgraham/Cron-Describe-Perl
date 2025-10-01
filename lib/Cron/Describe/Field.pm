# ABSTRACT: Base class for validating and describing cron expression fields
package Cron::Describe::Field;

use strict;
use warnings;
use Moo;
use Carp qw(croak);

has 'value'       => (is => 'ro', required => 1);
has 'min'         => (is => 'ro', required => 1);
has 'max'         => (is => 'ro', required => 1);
has 'allowed_specials' => (is => 'ro', default => sub { ['*', ',', '-', '/'] });
has 'allowed_names' => (is => 'ro', default => sub { {} });  # For month/day names

sub is_valid {
    my ($self) = @_;
    my $val = $self->value;
    my %errors;

    # Validate against allowed specials and names
    my $specials = join '|', map { quotemeta } @{$self->allowed_specials};
    my $names = join '|', keys %{$self->allowed_names};
    my $num_regex = qr/\d+/;
    my $range_regex = qr/(?:$num_regex|$names)-(?:$num_regex|$names)/;
    my $list_regex = qr/(?:$num_regex|$names|$range_regex)(?:,(?:$num_regex|$names|$range_regex))*/;
    my $step_regex = qr/(?:\*|$num_regex|$range_regex|$list_regex)\/(\d+)/;

    unless ($val =~ m{
        ^ (?: \* (?: / \d+ )? 
          | $range_regex (?: / \d+ )? 
          | $list_regex 
          | $num_regex
          | $names
          | $specials
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
        # Check step values
        if ($val =~ $step_regex) {
            my $step = $1;
            if ($step == 0) {
                $errors{step} = "Step value cannot be zero: $val";
            }
        }
    }

    return (scalar keys %errors == 0, \%errors);
}

sub describe {
    my ($self, $unit) = @_;
    my $val = $self->value;
    my $names = join '|', keys %{$self->allowed_names};

    if ($val eq '*') {
        return 'every';
    } elsif ($val =~ /^(\d+)$/) {
        return "at $1 $unit" . ($1 == 1 && $unit ne 'month' ? '' : 's');
    } elsif ($val =~ /^(\d+)-(\d+)$/) {
        return "from $1 to $2 $unit" . ($2 == 1 && $unit ne 'month' ? '' : 's');
    } elsif ($val =~ /^(?:(?:\d+|$names)(?:,(?:\d+|$names))*)$/) {
        my @parts = split /,/, $val;
        my @desc = map { $self->allowed_names->{$_} ? lc($_) : $_ } @parts;
        return "at " . join(',', @desc) . " $unit" . (@desc == 1 && $unit ne 'month' ? '' : 's');
    } elsif ($val =~ /^(.*?)(?:\/(\d+))$/) {
        my ($base, $step) = ($1, $2);
        my $base_desc = $base eq '*' ? 'every' : $self->new(value => $base, min => $self->min, max => $self->max)->describe($unit);
        return "every $step $unit" . ($step == 1 && $unit ne 'month' ? '' : 's') . ($base eq '*' ? '' : " $base_desc");
    } elsif ($self->allowed_names->{$val}) {
        return lc $val;
    }

    return $val;  # Fallback for special characters
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Field - Base class for validating and describing cron expression fields

=head1 DESCRIPTION

Handles generic field validation and description for cron expressions.

=head1 METHODS

=over 4

=item is_valid

Returns (boolean, \%errors) indicating if the field is valid.

=item describe($unit)

Returns a concise English description of the field value (e.g., 'every minutes', 'at 5 minutes', 'from 1 to 5 hours').

=back

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
