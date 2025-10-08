package Cron::Describe::SinglePattern;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    croak "Invalid value '$value' for $field_type, expected $min-$max" unless $value =~ /^\d+$/ && $value >= $min && $value <= $max;
    my $self = bless {}, $class;
    $self->{value} = $value;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return $value == $self->{value};
}

sub to_hash {
    my $self = shift;
    return {
        field_type => $self->{field_type},
        pattern_type => 'single',
        value => $self->{value},
        min => $self->{min},
        max => $self->{max},
        step => 1
    };
}

1;
