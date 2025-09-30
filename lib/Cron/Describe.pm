package Cron::Describe;

use strict;
use warnings;
use Moo;
use Carp qw(croak);
use Try::Tiny;
use DateTime::TimeZone;

our $VERSION = '0.001';

# Abstract base class - do not instantiate directly

sub new {
    my ($class, %args) = @_;
    my $cron_str = delete $args{cron_str} // croak "cron_str required";
    my $timezone = delete $args{timezone} // 'UTC';
    my $type     = delete $args{type};

    # Sanitize input: trim whitespace
    $cron_str =~ s/^\s+|\s+$//g;

    try {
        DateTime::TimeZone->new(name => $timezone);
    } catch {
        croak "Invalid timezone: $timezone";
    };

    # Heuristic to determine type
    my @fields = split /\s+/, $cron_str;
    my $field_count = scalar @fields;
    my $detected_type = $type;

    unless ($detected_type) {
        if ($field_count == 5) {
            $detected_type = 'standard';
        } elsif ($field_count == 6 || $field_count == 7) {
            $detected_type = 'quartz';
        } else {
            croak "Invalid cron expression: wrong number of fields ($field_count)";
        }

        # Check for Quartz-specific chars
        if ($cron_str =~ /[#?WL]/ && $detected_type eq 'standard') {
            croak "Invalid standard cron: Quartz-specific characters (#, ?, W, L) detected";
        }
    }

    my $subclass = $detected_type eq 'standard' ? 'Cron::Describe::Standard' : 'Cron::Describe::Quartz';
    require $subclass =~ s/::/\//gr . '.pm';

    return $subclass->new(
        cron_str => $cron_str,
        timezone => $timezone,
        %args,
    );
}

1;

__END__

=pod

=head1 NAME

Cron::Describe - Abstract base class for parsing and validating cron expressions

=head1 SYNOPSIS

  use Cron::Describe;
  my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?');
  if ($cron->is_valid) { ... }

=head1 DESCRIPTION

Base class for cron parsers. Use subclasses via factory.

=head1 METHODS

=over 4

=item new(%args)

Factory constructor. Args: C<cron_str> (required), C<timezone> (default 'UTC'), C<type> (optional: 'standard' or 'quartz').

=back

=cut
