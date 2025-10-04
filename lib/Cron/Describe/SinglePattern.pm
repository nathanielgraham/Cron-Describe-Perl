# File: lib/Cron/Describe/SinglePattern.pm
package Cron::Describe::SinglePattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max) = @_;
    my $self = bless {
        pattern_type => 'single',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        errors => [],
    }, $class;

    if ($value =~ m{^\d+$}) {
        my $num = $value + 0;
        if ($num >= $min && $num <= $max) {
            $self->{value} = $num;
            $self->{min_value} = $num;
            $self->{max_value} = $num;
        } else {
            push @{$self->{errors}}, "Value $num out of range [$min-$max]";
        }
    } else {
        push @{$self->{errors}}, "Invalid single pattern: $value";
    }
    return $self;
}

sub validate { return !shift->has_errors; }
sub is_match {
    my ($self, $value) = @_;
    return $value == $self->{value};
}
sub to_english {
    my ($self) = @_;
    return "at " . $self->{field_type} . " " . $self->{value};
}
sub to_string { return shift->{value}; }

1;
