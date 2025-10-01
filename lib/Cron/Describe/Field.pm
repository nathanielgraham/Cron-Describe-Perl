package Cron::Describe::Field;

use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    $self->{min} // die "No min for $args{type}";
    $self->{max} // die "No max for $args{type}";
    $self->parse();
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
    $name = lc $name;
    if ($self->{type} eq 'month') {
        my %months = (jan=>1, feb=>2, mar=>3, apr=>4, may=>5, jun=>6, jul=>7, aug=>8, sep=>9, oct=>10, nov=>11, dec=>12);
        return $months{$name};
    } elsif ($self->{type} eq 'dow') {
        my %dow = (sun=>0, mon=>1, tue=>2, wed=>3, thu=>4, fri=>5, sat=>6, sunday=>0, monday=>1, tuesday=>2, wednesday=>3, thursday=>4, friday=>5, saturday=>6);
        return $dow{$name};
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
