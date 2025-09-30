package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use Moo;
extends 'Cron::Describe::Field';

has '+min' => (default => 1);
has '+max' => (default => 7);
has '+allowed_specials' => (default => sub { [qw(* , - / ? L #)] });

my %names = (SUN => 1, MON => 2, TUE => 3, WED => 4, THU => 5, FRI => 6, SAT => 7);

around 'is_valid' => sub {
    my $orig = shift;
    my ($self) = @_;
    my ($valid, $errors) = $self->$orig();

    if ($self->value =~ /[A-Z]{3}/i) {
        my $name = uc($self->value);
        unless (exists $names{$name}) {
            $errors->{syntax} = "Invalid day name: $name";
        }
    } elsif ($self->value =~ /#/) {
        unless ($self->value =~ /^(\d+|SUN|MON|TUE|WED|THU|FRI|SAT)#([1-5])$/) {
            $errors->{syntax} = "Invalid # syntax: " . $self->value;
        }
    }

    return (scalar keys %errors == 0, $errors);
};

1;

__END__

=pod

=head1 NAME

Cron::Describe::DayOfWeek - Validator for cron DayOfWeek field

=head1 DESCRIPTION

Validates DayOfWeek field, including Quartz-specific # and names.

=cut
