# File: lib/Cron/Describe/WildcardPattern.pm
package Cron::Describe::WildcardPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = bless {
        pattern_type => 'wildcard',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        field_type   => $field_type,
        errors => [],
    }, $class;

    unless ($value eq '*') {
        push @{$self->{errors}}, "Invalid wildcard pattern: $value";
    }
    return $self;
}

sub validate { return !shift->has_errors; }
sub is_match { return 1; }
sub to_english { return "every " . shift->{field_type}; }
sub to_string { return "*"; }

1;
