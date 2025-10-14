package Cron::Describe::StepPattern;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::WildcardPattern;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: Cron::Describe::StepPattern: value='$value', field_type='$field_type', min=$min, max=$max\n" if $ENV{Cron_DEBUG};
    my ($base, $step) = split /\//, $value, 2;
    croak "Invalid step pattern '$value' for $field_type" unless defined $base && defined $step;
    croak "Step value $step is invalid for $field_type" unless $step =~ /^\d+$/ && $step > 0;

    my $base_pattern;
    if ($base eq '*') {
        $base_pattern = Cron::Describe::WildcardPattern->new($base, $min, $max, $field_type);
    } elsif ($base =~ /^\d+$/) {
        $base_pattern = Cron::Describe::SinglePattern->new($base, $min, $max, $field_type);
    } elsif ($base =~ /^\d+-\d+$/) {
        $base_pattern = Cron::Describe::RangePattern->new($base, $min, $max, $field_type);
    } else {
        croak "Invalid base pattern '$base' in step pattern for $field_type";
    }

    my $self = bless {
        value => $value,
        min => $min,
        max => $max,
        field_type => $field_type,
        base => $base_pattern,
        step => $step,
    }, $class;
    print STDERR "DEBUG: Cron::Describe::StepPattern: StepPattern: start_value=" . ($base_pattern->to_hash->{start_value} // $min) . ", end_value=" . ($base_pattern->to_hash->{end_value} // $max) . ", step=$step\n" if $ENV{Cron_DEBUG};
    return $self;
}

sub to_hash {
    my ($self) = @_;
    return {
        field_type => $self->{field_type},
        pattern_type => 'step',
        step => $self->{step},
        min => $self->{min},
        max => $self->{max},
        start_value => $self->{base}->to_hash->{start_value} // $self->{min},
        end_value => $self->{base}->to_hash->{end_value} // $self->{max},
        base => $self->{base}->to_hash,
    };
}

sub to_string {
    my ($self) = @_;
    return $self->{value};
}

sub is_match {
    my ($self, $value, $tm) = @_;
    print STDERR "DEBUG: is_match: StepPattern: value=$value, pattern_value=$self->{value}\n" if $ENV{Cron_DEBUG};
    my $base_hash = $self->{base}->to_hash;
    my $start = $base_hash->{start_value} // $self->{min};
    my $end = $base_hash->{end_value} // $self->{max};

    # For SinglePattern, use max as end to allow full sequence
    if ($self->{base}->isa('Cron::Describe::SinglePattern')) {
        $end = $self->{max};
    }
    return 0 unless $value >= $start && $value <= $end;
    return ($value - $start) % $self->{step} == 0;
}

1;
