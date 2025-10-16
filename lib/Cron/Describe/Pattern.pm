package Cron::Describe::Pattern;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    my $self = bless {
        value => $value,
        min => $min,
        max => $max,
        field_type => $field_type,
    }, $class;
    $self->_debug("$class: value='$value', field_type='$field_type', min=$min, max=$max");
    return $self;
}

sub is_match {
    croak "Abstract method 'is_match' not implemented in " . ref($_[0]);
}

sub to_english {
    croak "Abstract method 'to_english' not implemented in " . ref($_[0]);
}

sub to_string {
    croak "Abstract method 'to_string' not implemented in " . ref($_[0]);
}

sub is_single {
    my ($self, $value) = @_;
    return 0;  # DEFAULT: NOT SINGLE
}

sub to_hash {
    my ($self) = @_;
    return {
        pattern_type => $self->{pattern_type},
        field_type => $self->{field_type},
        min => $self->{min},
        max => $self->{max},
        step => $self->{step} // 1,
    };
}

sub _debug {
    my ($self, $message) = @_;
    print STDERR "DEBUG: " . ref($self) . ": $message\n" if $ENV{Cron_DEBUG};
}

1;
