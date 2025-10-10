package Cron::Describe::StepPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::WildcardPattern;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: StepPattern::new: value='$value', field_type='$field_type'\n" if $Cron::Describe::DEBUG;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'step';
    unless ($value =~ /^(\*|\d+|\d+-\d+)\/(\d+)$/) {
        $self->add_error("Invalid step pattern '$value' for $field_type");
        croak $self->errors->[0];
    }
    my ($base, $step) = ($1, $2);
    unless ($step > 0) {
        $self->add_error("Step value $step is invalid for $field_type");
        croak $self->errors->[0];
    }
    $self->{step} = $step;
    if ($base eq '*') {
        $self->{base} = Cron::Describe::WildcardPattern->new($base, $min, $max, $field_type);
        $self->{start_value} = $min;
        $self->{end_value} = $max;
    } elsif ($base =~ /^\d+$/) {
        $self->{base} = Cron::Describe::RangePattern->new($base . '-' . $max, $min, $max, $field_type);
        $self->{start_value} = $base;
        $self->{end_value} = $max;
    } elsif ($base =~ /^(\d+)-(\d+)$/) {
        $self->{base} = Cron::Describe::RangePattern->new($base, $min, $max, $field_type);
        $self->{start_value} = $1;
        $self->{end_value} = $2;
    }
    $self->validate();
    print STDERR "DEBUG: StepPattern: start_value=$self->{start_value}, end_value=$self->{end_value}, step=$self->{step}\n" if $Cron::Describe::DEBUG;
    return $self;
}

sub validate {
    my ($self) = @_;
    unless ($self->{step} > 0) {
        $self->add_error("Step value $self->{step} is invalid for $self->{field_type}");
    }
    $self->{base}->validate();
    croak join("; ", @{$self->errors}) if $self->has_errors;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $base_match = $self->{base}->is_match($value, $tm);
    my $range_match = $value >= $self->{start_value} && $value <= $self->{end_value};
    my $step_match = (($value - $self->{start_value}) % $self->{step}) == 0;
    my $result = $base_match && $range_match && $step_match;
    $self->_debug("is_match: value=$value, base_match=$base_match, range_match=$range_match, step_match=$step_match, result=$result");
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    $hash->{step} = $self->{step};
    $hash->{start_value} = $self->{start_value};
    $hash->{end_value} = $self->{end_value};
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return $self->{base}->to_string . "/$self->{step}";
}

sub to_english {
    my ($self) = @_;
    return "every $self->{step} starting from " . $self->{base}->to_english;
}

1;
