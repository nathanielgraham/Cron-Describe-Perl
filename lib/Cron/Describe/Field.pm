package Cron::Describe::Field;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{min} // die "No min for $args{type}";
    $self->{max} // die "No max for $args{type}";
    eval { $self->parse() };
    if ($@) {
        warn "Parse error for $self->{type}: $@";
        $self->{parsed} = [{ type => '*' }]; # Fallback to wildcard
    }
    return $self;
}

sub parse {
    my $self = shift;
    my $value = $self->{value} // '*';
    my @parts = split /,/, $value;
    $self->{parsed} = [];
    foreach my $part (@parts) {
        $part =~ s/^\s+|\s+$//g;
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
        } elsif (my $num = $self->_name_to_num($part)) {
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
        push @{$self->{parsed}}, $struct;
    }
}

sub _name_to_num {
    my ($self, $name) = @_;
    my $upper = uc $name;
    my $lower = lc $name;
    if ($self->{type} eq 'month') {
        my %months = (
            JAN=>1, jan=>1, FEB=>2, feb=>2, MAR=>3, mar=>3, APR=>4, apr=>4,
            MAY=>5, may=>5, JUN=>6, jun=>6, JUL=>7, jul=>7, AUG=>8, aug=>8,
            SEP=>9, sep=>9, OCT=>10, oct=>10, NOV=>11, nov=>11, DEC=>12, dec=>12
        );
        return $months{$upper} || $months{$lower};
    } elsif ($self->{type} eq 'dow') {
        my %dow = (
            SUN=>0, sun=>0, MON=>1, mon=>1, TUE=>2, tue=>2, WED=>3, wed=>3,
            THU=>4, thu=>4, FRI=>5, fri=>5, SAT=>6, sat=>6,
            SUNDAY=>0, sunday=>0, MONDAY=>1, monday=>1, TUESDAY=>2, tuesday=>2,
            WEDNESDAY=>3, wednesday=>3, THURSDAY=>4, thursday=>4, FRIDAY=>5, friday=>5,
            SATURDAY=>6, saturday=>6
        );
        return $dow{$upper} || $dow{$lower};
    }
    return undef;
}

sub validate {
    my $self = shift;
    eval { $self->parse() };
    return $@ ? 0 : 1;
}

sub matches {
    my ($self, $time_parts) = @_;
    my $val = $time_parts->{$self->{type}};
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq '*' || $struct->{type} eq '?') {
            return 1;
        }
        if ($struct->{type} eq 'range' || $struct->{type} eq 'single') {
            return 1 if $val >= $struct->{min} && $val <= $struct->{max} && ($val - $struct->{min}) % $struct->{step} == 0;
        } elsif ($struct->{type} eq 'step') {
            return 1 if ($val - $self->{min}) % $struct->{step} == 0;
        }
    }
    return 0;
}

sub to_english {
    my $self = shift;
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
    return join(', ', @phrases) || "every $self->{type}";
}

1;
