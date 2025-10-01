package Cron::Describe::Field;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{min} // die "No min for $args{field_type}";
    $self->{max} // die "No max for $args{field_type}";
    print STDERR "DEBUG: Field.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{field_type}\n";
    return $self;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $val = $time_parts->{$self->{field_type}};
    print STDERR "DEBUG: Checking if $self->{field_type} value $val matches\n";
    if ($self->{pattern_type} eq 'wildcard' || $self->{pattern_type} eq 'unspecified') {
        print STDERR "DEBUG: $self->{field_type} matches (wildcard)\n";
        return 1;
    }
    if ($self->{pattern_type} eq 'single') {
        if ($val == $self->{value}) {
            print STDERR "DEBUG: $self->{field_type} matches single: $val\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'range') {
        if ($val >= $self->{min_value} && $val <= $self->{max_value} && ($val - $self->{min_value}) % $self->{step} == 0) {
            print STDERR "DEBUG: $self->{field_type} matches range: $val in $self->{min_value}-$self->{max_value}/$self->{step}\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'step') {
        if (($val - $self->{min_value}) % $self->{step} == 0) {
            print STDERR "DEBUG: $self->{field_type} matches step: $val with step $self->{step}\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'list') {
        for my $sub (@{$self->{sub_patterns}}) {
            if ($sub->{pattern_type} eq 'single' && $val == $sub->{value}) {
                print STDERR "DEBUG: $self->{field_type} matches list single: $val\n";
                return 1;
            } elsif ($sub->{pattern_type} eq 'range' && $val >= $sub->{min_value} && $val <= $sub->{max_value} && ($val - $sub->{min_value}) % $sub->{step} == 0) {
                print STDERR "DEBUG: $self->{field_type} matches list range: $val\n";
                return 1;
            }
        }
    }
    print STDERR "DEBUG: $self->{field_type} does not match\n";
    return 0;
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english for $self->{field_type}\n";
    if ($self->{pattern_type} eq 'wildcard' || $self->{pattern_type} eq 'unspecified') {
        print STDERR "DEBUG: to_english for $self->{field_type}: every $self->{field_type}\n";
        return "every $self->{field_type}";
    } elsif ($self->{pattern_type} eq 'single') {
        print STDERR "DEBUG: to_english for $self->{field_type}: $self->{value}\n";
        return $self->{value};
    } elsif ($self->{pattern_type} eq 'range') {
        my $desc = "$self->{min_value}-$self->{max_value}" . ($self->{step} > 1 ? " every $self->{step}" : "");
        print STDERR "DEBUG: to_english for $self->{field_type}: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'step') {
        my $desc = "every $self->{step} $self->{field_type}s";
        print STDERR "DEBUG: to_english for $self->{field_type}: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'list') {
        my @sub_descs = map { $self->to_english($_) } @{$self->{sub_patterns}};
        my $desc = join(', ', @sub_descs);
        print STDERR "DEBUG: to_english for $self->{field_type}: $desc\n";
        return $desc;
    }
    my $desc = "every $self->{field_type}";
    print STDERR "DEBUG: to_english for $self->{field_type}: $desc\n";
    return $desc;
}

1;
