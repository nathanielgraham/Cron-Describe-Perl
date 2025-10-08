package Cron::Describe::WildcardPattern;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: WildcardPattern::new: value='$value', field_type='$field_type'\n";
    croak "Invalid wildcard '$value' for $field_type, expected '*'" unless $value eq '*';
    my $self = bless {}, $class;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    return $value >= $self->{min} && $value <= $self->{max};
}

sub to_hash {
    my $self = shift;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => 'wildcard',
        min => $self->{min},
        max => $self->{max},
        step => 1
    };
    print STDERR "DEBUG: WildcardPattern::to_hash: " . join(", ", map { "$_=$hash->{$_}" } keys %$hash) . "\n";
    return $hash;
}

1;
