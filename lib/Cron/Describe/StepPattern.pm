package Cron::Describe::StepPattern;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::WildcardPattern;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: StepPattern::new: value='$value', field_type='$field_type'\n";
    croak "Invalid step pattern '$value' for $field_type" unless $value =~ /^(\*|\d+|\d+-\d+)\/(\d+)$/;
    my ($base, $step) = ($1, $2);
    croak "Step value $step is invalid for $field_type" unless $step > 0;
    my $self = bless {}, $class;
    $self->{step} = $step;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;

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
    print STDERR "DEBUG: StepPattern: start_value=$self->{start_value}, end_value=$self->{end_value}, step=$self->{step}\n";
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return 0 unless $self->{base}->is_match($value, $tm);
    return 0 unless $value >= $self->{start_value} && $value <= $self->{end_value};
    return (($value - $self->{start_value}) % $self->{step}) == 0;
}

sub to_hash {
    my $self = shift;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => 'step',
        start_value => $self->{start_value},
        end_value => $self->{end_value},
        step => $self->{step},
        min => $self->{min},
        max => $self->{max}
    };
    print STDERR "DEBUG: StepPattern::to_hash: " . join(", ", map { "$_=$hash->{$_}" } keys %$hash) . "\n";
    return $hash;
}

1;
