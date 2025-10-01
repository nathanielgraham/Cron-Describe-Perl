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
        if (($val - $self->{start_value}) % $self->{step} == 0) {
            print STDERR "DEBUG: $self->{field_type} matches step: $val with step $self->{step}\n";
            return 1;
        }
    } elsif ($self->{pattern_type} eq 'list') {
        for my $i (0 .. $#{$self->{sub_patterns}}) {
            my $sub = $self->{sub_patterns}[$i];
            print STDERR "DEBUG: Processing sub-pattern $i for list in $self->{field_type}\n";
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
    my ($self, %options) = @_;
    my $expand_steps = $options{expand_steps} // 0;
    my $type = $self->{field_type};
    print STDERR "DEBUG: Generating to_english for $type (expand_steps=$expand_steps)\n";
    if ($self->{pattern_type} eq 'wildcard' || $self->{pattern_type} eq 'unspecified') {
        my $desc = "every $type";
        print STDERR "DEBUG: to_english for $type: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'single') {
        my $desc;
        if ($type eq 'dow') {
            my %dow_names = (0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday');
            $desc = $dow_names{$self->{value}} || sprintf("%02d", $self->{value});
        } elsif ($type eq 'month') {
            my %month_names = (1 => 'January', 2 => 'February', 3 => 'March', 4 => 'April', 5 => 'May', 6 => 'June',
                               7 => 'July', 8 => 'August', 9 => 'September', 10 => 'October', 11 => 'November', 12 => 'December');
            $desc = $month_names{$self->{value}} || sprintf("%02d", $self->{value});
        } else {
            $desc = sprintf("%02d", $self->{value});
        }
        print STDERR "DEBUG: to_english for $type: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'range') {
        my $desc = sprintf("%02d-%02d", $self->{min_value}, $self->{max_value}) . ($self->{step} > 1 ? " every $self->{step}" : "");
        print STDERR "DEBUG: to_english for $type: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'step') {
        my $desc;
        if ($expand_steps) {
            my @values;
            for (my $v = $self->{start_value}; $v <= $self->{max_value}; $v += $self->{step}) {
                push @values, sprintf("%02d", $v);
            }
            $desc = join(',', @values);
        } else {
            $desc = $self->{step} == 1 ? sprintf("%02d", $self->{start_value}) :
                    "every $self->{step} ${type}s starting at " . sprintf("%02d", $self->{start_value});
        }
        print STDERR "DEBUG: to_english for $type: $desc\n";
        return $desc;
    } elsif ($self->{pattern_type} eq 'list') {
        my @sub_descs;
        for my $i (0 .. $#{$self->{sub_patterns}}) {
            my $sub = $self->{sub_patterns}[$i];
            print STDERR "DEBUG: Processing sub-pattern $i for list in $type\n";
            my $sub_field = bless { %$sub, field_type => $type }, ref($self);
            push @sub_descs, $sub_field->to_english(expand_steps => $expand_steps);
        }
        my $desc = join(',', @sub_descs); # No space after comma
        print STDERR "DEBUG: to_english for $type: $desc\n";
        return $desc;
    }
    my $desc = "every $type";
    print STDERR "DEBUG: to_english for $type: $desc\n";
    return $desc;
}
1;
