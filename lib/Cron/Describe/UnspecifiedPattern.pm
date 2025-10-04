# File: lib/Cron/Describe/UnspecifiedPattern.pm
package Cron::Describe::UnspecifiedPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';
use Carp;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    croak "Value, min, max, and field_type required" unless defined $value && defined $min && defined $max && defined $field_type;

    my $self = bless {
        pattern_type => 'unspecified',
        min_value    => $min,
        max_value    => $max,
        raw_value    => $value,
        field_type   => $field_type,
        errors       => [],
    }, $class;

    unless ($value eq '?') {
        push @{$self->{errors}}, "Invalid unspecified pattern: $value for $field_type";
    }
    if ($field_type !~ /^(day_of_month|day_of_week)$/) {
        push @{$self->{errors}}, "Unspecified pattern '?' is only valid for day_of_month or day_of_week, not $field_type";
    }

    return $self;
}

sub validate {
    my ($self) = @_;
    return !@{$self->{errors}};
}

sub has_errors {
    my ($self) = @_;
    return @{$self->{errors}} > 0;
}

sub is_match {
    my ($self, $value) = @_;
    croak "No valid value defined" if $self->has_errors;
    return 1;
}

sub to_english {
    my ($self) = @_;
    croak "No valid value defined" if $self->has_errors;
    return "any $self->{field_type}";
}

sub to_string {
    my ($self) = @_;
    return '?';
}

1;
