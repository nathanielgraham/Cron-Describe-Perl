# File: lib/Cron/Describe/StepPattern.pm
package Cron::Describe::StepPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max) = @_;
    my $self = bless {
        pattern_type => 'step',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        errors => [],
    }, $class;

    if ($value =~ m{^(.+)/(\d+)$}) {
        my ($base_value, $step) = ($1, $2 + 0);
        if ($step <= 0) {
            push @{$self->{errors}}, "Step must be > 0: $value";
            return $self;
        }
        my $base = Cron::Describe::Pattern->new($base_value, $min, $max);
        if ($base->has_errors) {
            push @{$self->{errors}}, @{ $base->{errors} };
            return $self;
        }
        $self->{base} = $base;
        $self->{step} = $step;
        $self->{start_value} = $base->{min_value} // $min;
        $self->{min_value} = $base->{min_value} // $min;
        $self->{max_value} = $base->{max_value} // $max;
    } else {
        push @{$self->{errors}}, "Invalid step pattern: $value";
    }
    return $self;
}

sub validate {
    my ($self) = @_;
    return ! $self->has_errors;
}

sub is_match {
    my ($self, $value) = @_;
    return 0 unless $self->{base}->is_match($value);
    return ($value - $self->{start_value}) % $self->{step} == 0;
}

sub to_english {
    my ($self) = @_;
    my $base_desc = $self->{base}{pattern_type} eq 'range'
        ? "from $self->{base}{min} to $self->{base}{max}"
        : "every $self->{field_type}";
    return "every $self->{step} $self->{field_type} $base_desc";
}

sub to_string {
    my ($self) = @_;
    return $self->{base}->to_string . "/" . $self->{step};
}

1;
