package Cron::Describe::Field;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    print STDERR "DEBUG: Field.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{field_type}\n";
    return $self;
}

sub to_english {
    my ($self, %args) = @_;
    my $expand_steps = $args{expand_steps} // 0;
    my $type = $self->{field_type};
    my $pattern = $self->{pattern_type} // 'error';
    my $name = $type eq 'dom' ? 'day-of-month' : $type eq 'dow' ? 'day-of-week' : $type;

    print STDERR "DEBUG: Generating to_english for $type, pattern=$pattern\n";
    if ($pattern eq 'wildcard') {
        my $desc = "every $name";
        print STDERR "DEBUG: $type wildcard: $desc\n";
        return $desc;
    } elsif ($pattern eq 'unspecified') {
        print STDERR "DEBUG: $type unspecified: null\n";
        return undef;
    } elsif ($pattern eq 'single') {
        my $desc = "$self->{value} $name" . ($self->{value} == 1 ? '' : 's');
        print STDERR "DEBUG: $type single: $desc\n";
        return $desc;
    } elsif ($pattern eq 'range') {
        my $desc = "$self->{min_value} to $self->{max_value} $name" . ($self->{max_value} == 1 ? '' : 's');
        print STDERR "DEBUG: $type range: $desc\n";
        return $desc;
    } elsif ($pattern eq 'step') {
        my $desc = $expand_steps
            ? "every $self->{step} $name" . ($self->{step} == 1 ? '' : 's') . " starting at $self->{start_value}"
            : do {
                my @values;
                for (my $i = $self->{start_value}; $i <= $self->{max_value}; $i += $self->{step}) {
                    push @values, $i;
                }
                join(", ", @values) . " $name" . (@values == 1 ? '' : 's');
            };
        print STDERR "DEBUG: $type step: $desc\n";
        return $desc;
    } elsif ($pattern eq 'list') {
        my @subs = map { $_->to_english(%args) } @{$self->{sub_patterns}};
        my $desc = join(", ", @subs) . " $name" . (@subs == 1 ? '' : 's');
        print STDERR "DEBUG: $type list: $desc\n";
        return $desc;
    }
    my $desc = "invalid $name";
    print STDERR "DEBUG: $type error: $desc\n";
    return $desc;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $type = $self->{field_type};
    my $pattern = $self->{pattern_type} // 'error';
    my $value = $time_parts->{$type};

    print STDERR "DEBUG: Checking $type match: value=$value, pattern=$pattern\n";
    return 0 if $pattern eq 'error';
    if ($pattern eq 'wildcard' || $pattern eq 'unspecified') {
        print STDERR "DEBUG: $type matches: wildcard/unspecified\n";
        return 1;
    }
    if ($pattern eq 'single') {
        my $result = $self->{value} == $value;
        print STDERR "DEBUG: $type single match: $result\n";
        return $result;
    }
    if ($pattern eq 'range') {
        my $result = $value >= $self->{min_value} && $value <= $self->{max_value};
        print STDERR "DEBUG: $type range match: $result\n";
        return $result;
    }
    if ($pattern eq 'step') {
        my $result = ($value - $self->{start_value}) % $self->{step} == 0 && $value >= $self->{start_value} && $value <= $self->{max_value};
        print STDERR "DEBUG: $type step match: $result\n";
        return $result;
    }
    if ($pattern eq 'list') {
        my $result = grep { $_->matches($time_parts) } @{$self->{sub_patterns}};
        print STDERR "DEBUG: $type list match: $result\n";
        return $result;
    }
    print STDERR "DEBUG: $type does not match\n";
    return 0;
}

1;
