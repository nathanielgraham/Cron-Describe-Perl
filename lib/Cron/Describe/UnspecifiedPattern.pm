# File: lib/Cron/Describe/UnspecifiedPattern.pm
package Cron::Describe::UnspecifiedPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max) = @_;
    my $self = bless {
        pattern_type => 'unspecified',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        errors => [],
    }, $class;

    unless ($value eq '?') {
        push @{$self->{errors}}, "Invalid unspecified pattern: $value";
    }
    return $self;
}

sub validate { return !shift->has_errors; }
sub is_match { return 1; }
sub to_english { return "any " . shift->{field_type}; }
sub to_string { return "?"; }

1;
