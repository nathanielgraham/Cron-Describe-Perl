package Cron::Describe::Field;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    print STDERR "DEBUG: Field.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $args{field_type}\n";
    $self->{parent} = $args{parent} if $args{parent}; # Store parent for date calculations
    return $self;
}

sub to_english {
    my ($self, %args) = @_;
    my $type = $self->{field_type};
    my $pattern = $self->{pattern_type};
    my $plural = $type =~ /^(seconds|minute)$/ ? 's' : '';
    my %month_names = (1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April', 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'August', 9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December');
    if ($pattern eq 'single') {
        if ($type =~ /^(seconds|minute|hour)$/) {
            return sprintf("%02d", $self->{value});
        } elsif ($type eq 'month' && exists $month_names{$self->{value}}) {
            return $month_names{$self->{value}};
        }
        return $self->{value};
    } elsif ($pattern eq 'wildcard') {
        return "every $type$plural";
    } elsif ($pattern eq 'unspecified') {
        return "any $type$plural";
    } elsif ($pattern eq 'range') {
        if ($type eq 'month') {
            return "every $type$plural from $month_names{$self->{min_value}} to $month_names{$self->{max_value}}" . ($self->{step} > 1 ? " stepping by $self->{step}" : "");
        }
        return "every $type$plural from $self->{min_value} to $self->{max_value}" . ($self->{step} > 1 ? " stepping by $self->{step}" : "");
    } elsif ($pattern eq 'step') {
        return "every $self->{step} $type$plural starting at $self->{start_value}";
    } elsif ($pattern eq 'list') {
        my @values = map { $_->{pattern_type} eq 'single' ? ($type eq 'month' && exists $month_names{$_->{value}} ? $month_names{$_->{value}} : $_->{value}) : "$_->{min_value}-$_->{max_value}" } @{$self->{sub_patterns}};
        return join(", ", @values) . " $type$plural";
    }
    return "invalid $type$plural";
}

sub matches {
    my ($self, $time_parts) = @_;
    my $type = $self->{field_type};
    my $val = $time_parts->{$type};
    my $pattern = $self->{pattern_type};
    print STDERR "DEBUG: Matching $type value $val against pattern $pattern\n" if $self->{parent}{debug};
    if ($pattern eq 'single') {
        return $val == $self->{value};
    } elsif ($pattern eq 'wildcard' || $pattern eq 'unspecified') {
        return 1;
    } elsif ($pattern eq 'range') {
        return $val >= $self->{min_value} && $val <= $self->{max_value} && ($val - $self->{min_value}) % $self->{step} == 0;
    } elsif ($pattern eq 'step') {
        return $val >= $self->{start_value} && ($val - $self->{start_value}) % $self->{step} == 0;
    } elsif ($pattern eq 'list') {
        for my $sub (@{$self->{sub_patterns}}) {
            if ($sub->{pattern_type} eq 'single') {
                return 1 if $val == $sub->{value};
            } elsif ($sub->{pattern_type} eq 'range') {
                return 1 if $val >= $sub->{min_value} && $val <= $sub->{max_value} && ($val - $sub->{min_value}) % $sub->{step} == 0;
            } elsif ($sub->{pattern_type} eq 'step') {
                return 1 if $val >= $sub->{start_value} && ($val - $sub->{start_value}) % $sub->{step} == 0;
            }
        }
        return 0;
    }
    return 0;
}

1;
