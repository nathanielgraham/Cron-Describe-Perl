package Cron::Describe::Pattern;
use strict;
use warnings;
use Carp qw(croak);
use Scalar::Util qw(blessed);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = bless {
        value => $value,
        min => $min,
        max => $max,
        field_type => $field_type,
        errors => [],
    }, $class;
    return $self;
}

sub validate {
    croak "Abstract method 'validate' not implemented in " . blessed($_[0]);
}

sub add_error {
    my ($self, $error) = @_;
    push @{$self->{errors}}, $error;
}

sub errors {
    my ($self) = @_;
    return $self->{errors} || [];
}

sub has_errors {
    my ($self) = @_;
    return @{$self->errors} > 0;
}

sub to_hash {
    my ($self) = shift;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => $self->{pattern_type} || 'unknown',
        min => $self->{min},
        max => $self->{max},
        step => $self->{step} // 1,
    };
    return $hash;
}

sub to_string {
    my ($self) = @_;
    croak "Abstract method 'to_string' not implemented in " . blessed($_[0]);
}

sub to_english {
    my ($self) = @_;
    croak "Abstract method 'to_english' not implemented in " . blessed($_[0]);
}

sub is_match {
    my ($self, $value, $tm) = @_;
    croak "Abstract method 'is_match' not implemented in " . blessed($_[0]);
}

sub _debug {
    my ($self, $message) = @_;
    print STDERR "DEBUG: " . ref($self) . ": $message\n" if $Cron::Describe::DEBUG;
}

1;
