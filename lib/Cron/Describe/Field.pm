package Cron::Describe::Field;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{min} // die "No min for $args{type}";
    $self->{max} // die "No max for $args{type}";
    print STDERR "DEBUG: Field.pm loaded (mtime: " . (stat(__FILE__))[9] . ") for type $self->{type}\n";
    eval { $self->parse() };
    if ($@) {
        warn "Parse error for $self->{type}: $@";
        $self->{parsed} = [{ type => '*' }]; # Fallback to wildcard
        print STDERR "DEBUG: Fallback to wildcard for $self->{type}\n";
    }
    return $self;
}

sub parse {
    my $self = shift;
    my $value = $self->{value} // '*';
    print STDERR "DEBUG: Parsing field $self->{type} with value=$value\n";
    my @parts = split /,/, $value;
    $self->{parsed} = [];
    foreach my $part (@parts) {
        $part =~ s/^\s+|\s+$//g;
        print STDERR "DEBUG: Processing part '$part' for $self->{type}\n";
        my $struct = {};
        if ($part eq '*' || $part eq '?') {
            $struct->{type} = $part;
        } elsif ($part =~ /^(\d+)-(\d+)(?:\/(\d+))?$/) {
            $struct->{type} = 'range';
            $struct->{min} = $1;
            $struct->{max} = $2;
            $struct->{step} = $3 // 1;
        } elsif ($part =~ /^(\d+)(?:\/(\d+))?$/) {
            $struct->{type} = 'single';
            $struct->{min} = $struct->{max} = $1;
            $struct->{step} = $2 // 1;
        } elsif ($part =~ /^\*\/(\d+)$/) {
            $struct->{type} = 'step';
            $struct->{min} = $self->{min};
            $struct->{max} = $self->{max};
            $struct->{step} = $1;
        } elsif (defined(my $num = $self->_name_to_num($part))) {
            $struct->{type} = 'single';
            $struct->{min} = $struct->{max} = $num;
            $struct->{step} = 1;
        } else {
            die "Invalid format: $part for $self->{type}";
        }
        # Bounds check after parsing
        if ($struct->{type} ne '*' && $struct->{type} ne '?') {
            if ($struct->{min} < $self->{min} || $struct->{max} > $self->{max} || $struct->{step} <= 0) {
                die "Out of bounds: $part for $self->{type}";
            }
        }
        print STDERR "DEBUG: Parsed part '$part' as type=$struct->{type}, min=" . ($struct->{min} // 'undef') . ", max=" . ($struct->{max} // 'undef') . ", step=" . ($struct->{step} // 'undef') . "\n";
        push @{$self->{parsed}}, $struct;
    }
}

sub _name_to_num {
    my ($self, $name) = @_;
    print STDERR "DEBUG: Mapping name '$name' for $self->{type}\n";
    if ($self->{type} eq 'month') {
        my %months = (
            JAN=>1, FEB=>2, MAR=>3, APR=>4, MAY=>5, JUN=>6,
            JUL=>7, AUG=>8, SEP=>9, OCT=>10, NOV=>11, DEC=>12
        );
        my $num = $months{$name};
        print STDERR "DEBUG: Month name '$name' mapped to " . ($num // 'undef') . "\n";
        return $num if defined $num;
    } elsif ($self->{type} eq 'dow') {
        my %dow = (
            SUN=>0, MON=>1, TUE=>2, WED=>3, THU=>4, FRI=>5, SAT=>6,
            SUNDAY=>0, MONDAY=>1, TUESDAY=>2, WEDNESDAY=>3, THURSDAY=>4, FRIDAY=>5, SATURDAY=>6
        );
        my $num = $dow{$name};
        print STDERR "DEBUG: DOW name '$name' mapped to " . ($num // 'undef') . "\n";
        return $num if defined $num;
    }
    return undef;
}

sub validate {
    my $self = shift;
    print STDERR "DEBUG: Validating field $self->{type}\n";
    eval { $self->parse() };
    my $result = $@ ? 0 : 1;
    print STDERR "DEBUG: Validation result for $self->{type}: $result\n";
    return $result;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $val = $time_parts->{$self->{type}};
    print STDERR "DEBUG: Checking if $self->{type} value $val matches\n";
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq '*' || $struct->{type} eq '?') {
            print STDERR "DEBUG: $self->{type} matches (wildcard)\n";
            return 1;
        }
        if ($struct->{type} eq 'range' || $struct->{type} eq 'single') {
            if ($val >= $struct->{min} && $val <= $struct->{max} && ($val - $struct->{min}) % $struct->{step} == 0) {
                print STDERR "DEBUG: $self->{type} matches range/single: $val in $struct->{min}-$struct->{max}/$struct->{step}\n";
                return 1;
            }
        } elsif ($struct->{type} eq 'step') {
            if (($val - $self->{min}) % $struct->{step} == 0) {
                print STDERR "DEBUG: $self->{type} matches step: $val with step $struct->{step}\n";
                return 1;
            }
        }
    }
    print STDERR "DEBUG: $self->{type} does not match\n";
    return 0;
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english for $self->{type}\n";
    my @phrases;
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq '*' || $struct->{type} eq '?') {
            push @phrases, "every $self->{type}";
        } elsif ($struct->{type} eq 'step') {
            push @phrases, "every $struct->{step} $self->{type}s";
        } elsif ($struct->{min} == $struct->{max}) {
            push @phrases, $struct->{min};
        } else {
            push @phrases, "$struct->{min}-$struct->{max}" . ($struct->{step} > 1 ? " every $struct->{step}" : "");
        }
    }
    my $result = join(', ', @phrases) || "every $self->{type}";
    print STDERR "DEBUG: to_english for $self->{type}: $result\n";
    return $result;
}

1;
