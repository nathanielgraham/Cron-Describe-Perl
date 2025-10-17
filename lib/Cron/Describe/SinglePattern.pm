package Cron::Describe::SinglePattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';
use Cron::Describe::Utils qw(:all);

sub to_english {
    my ($self, $field_type) = @_;
    my $value = $self->{value};
    return $day_names[$value] if $field_type eq 'dow';
    return $month_names[$value] if $field_type eq 'month';
    return num_to_ordinal($value) if $field_type eq 'dom';
    return $value;
}

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'single';
    $self->{value} = $value;
    croak "Invalid value '$value' for $field_type, expected $min-$max" unless $value =~ /^\d+$/ && $value >= $min && $value <= $max;
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return $value == $self->{value};
}

sub to_string {
    my ($self) = @_;
    return "$self->{value}";
}

sub is_single {
    my ($self, $value) = @_;
    return defined $value ? $self->{value} == $value : 1;
}

sub to_hash {
    my ($self) = @_;
    my $hash = $self->SUPER::to_hash;
    $hash->{value} = $self->{value};
    $hash->{start_value} = $self->{value};
    $hash->{end_value} = $self->{value};  # For single value, start and end are the same
    return $hash;
}

1;
