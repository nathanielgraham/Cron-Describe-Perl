package Cron::Describe::SinglePattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';
use Carp;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    croak "Value, min, max, and field_type required" unless defined $value && defined $min && defined $max && defined $field_type;

    my $self = bless {
        pattern_type => 'single',
        min_value    => $min,
        max_value    => $max,
        raw_value    => $value,
        field_type   => $field_type,
        errors       => [],
    }, $class;

    if ($value =~ m{^\d+$}) {
        my $num = $value + 0;
        if ($num >= $min && $num <= $max) {
            $self->{value} = $num;
            $self->{min_value} = $num;
            $self->{max_value} = $num;
        } else {
            push @{$self->{errors}}, "Value $num out of range [$min-$max] for $field_type";
        }
    } else {
        push @{$self->{errors}}, "Invalid single pattern: $value for $field_type";
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
    return $value == $self->{value};
}

sub to_english {
    my ($self) = @_;
    croak "No valid value defined" if $self->has_errors;
    return "at $self->{field_type} $self->{value}";
}

sub to_string {
    my ($self) = @_;
    croak "No valid value defined" if $self->has_errors;
    return $self->{value};
}

1;
