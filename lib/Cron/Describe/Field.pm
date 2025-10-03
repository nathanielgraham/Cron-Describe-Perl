package Cron::Describe::Field;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, %args) = @_;
    my $self = {
        field_type => $args{field_type} || croak "field_type is required",
        value => $args{value} // croak "value is required",
        range => $args{range} || [0, 59],
        pattern_type => 'error',
        min => $args{range}->[0],
        max => $args{range}->[1]
    };
    print "DEBUG: Field.pm new: field_type=$self->{field_type}, value=", (defined $self->{value} ? "'$self->{value}'" : 'undef'), ", range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
    bless $self, $class;
    $self->parse($self->{value});
    return $self;
}

sub parse {
    my ($self, $value) = @_;
    print "DEBUG: Parsing field $self->{field_type} with value ", (defined $value ? "'$value'" : 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;

    if (!defined $value || $value eq '') {
        $self->{pattern_type} = 'error';
        print "DEBUG: No pattern matched for $self->{field_type} with undefined or empty value, marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value eq '*') {
        $self->{pattern_type} = 'wildcard';
        print "DEBUG: Matched wildcard for $self->{field_type}, pattern_type=wildcard\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value =~ /^(\d+)$/) {
        my $num = $1;
        print "DEBUG: Testing single pattern for $self->{field_type}, value='$num', range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($num >= $self->{min} && $num <= $self->{max}) {
            $self->{pattern_type} = 'single';
            $self->{value} = "$num";
            $self->{min_value} = "$num";
            $self->{max_value} = "$num";
            $self->{step} = "1";
            print "DEBUG: Matched single for $self->{field_type}, value=$self->{value}, min_value=$self->{min_value}, max_value=$self->{max_value}, step=$self->{step}\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Single value '$num' out of range [$self->{min},$self->{max}] for $self->{field_type}\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /^(\d+)-(\d+)$/) {
        my ($min, $max) = ($1 + 0, $2 + 0);
        print "DEBUG: Testing range pattern for $self->{field_type}, min=$min, max=$max, range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($min >= $self->{min} && $max <= $self->{max} && $min <= $max) {
            $self->{pattern_type} = 'range';
            $self->{min_value} = "$min";
            $self->{max_value} = "$max";
            print "DEBUG: Matched range for $self->{field_type}, min_value=$self->{min_value}, max_value=$self->{max_value}\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Range min=$min, max=$max invalid for $self->{field_type}, range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /^(\d+)\/(\d+)$/) {
        my ($start, $step) = ($1 + 0, $2 + 0);
        print "DEBUG: Testing step pattern for $self->{field_type}, start=$start, step=$step, range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($start >= $self->{min} && $start <= $self->{max} && $step > 0) {
            $self->{pattern_type} = 'step';
            $self->{start_value} = "$start";
            $self->{step} = "$step";
            print "DEBUG: Matched step for $self->{field_type}, start_value=$self->{start_value}, step=$self->{step}\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Step start=$start, step=$step invalid for $self->{field_type}, range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /^\*\/(\d+)$/) {
        my $step = $1 + 0;
        print "DEBUG: Testing wildcard/step pattern for $self->{field_type}, step=$step\n" if $Cron::Describe::Quartz::DEBUG;
        if ($step > 0) {
            $self->{pattern_type} = 'step';
            $self->{start_value} = "$self->{min}";
            $self->{step} = "$step";
            print "DEBUG: Matched wildcard/step for $self->{field_type}, start_value=$self->{start_value}, step=$self->{step}\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Invalid wildcard/step step=$step for $self->{field_type}\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /^(\d+)-(\d+)\/(\d+)$/) {
        my ($min, $max, $step) = ($1 + 0, $2 + 0, $3 + 0);
        print "DEBUG: Testing range/step pattern for $self->{field_type}, min=$min, max=$max, step=$step, range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($min >= $self->{min} && $max <= $self->{max} && $min <= $max && $step > 0) {
            $self->{pattern_type} = 'step';
            $self->{start_value} = "$min";
            $self->{max_value} = "$max";
            $self->{step} = "$step";
            print "DEBUG: Matched range/step for $self->{field_type}, start_value=$self->{start_value}, max_value=$self->{max_value}, step=$self->{step}\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Invalid range/step min=$min, max=$max, step=$step for $self->{field_type}, range=[$self->{min},$self->{max}]\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    $self->{pattern_type} = 'error';
    print "DEBUG: No pattern matched for $self->{field_type} with value '$value', marking as error\n" if $Cron::Describe::Quartz::DEBUG;
}

sub is_match {
    my ($self, $value) = @_;
    print "DEBUG: is_match for $self->{field_type}, pattern_type=", ($self->{pattern_type} // 'undef'), ", testing value=$value\n" if $Cron::Describe::Quartz::DEBUG;
    return 0 if ($self->{pattern_type} || '') eq 'error';
    if (($self->{pattern_type} || '') eq 'wildcard') {
        print "DEBUG: Wildcard match for $self->{field_type}, value=$value, returning 1\n" if $Cron::Describe::Quartz::DEBUG;
        return 1;
    }
    if (($self->{pattern_type} || '') eq 'single') {
        my $result = $value == ($self->{value} // 0);
        print "DEBUG: Single match for $self->{field_type}, value=$value, expected=$self->{value}, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'range') {
        my $result = $value >= ($self->{min_value} // 0) && $value <= ($self->{max_value} // 0);
        print "DEBUG: Range match for $self->{field_type}, value=$value, range=[$self->{min_value},$self->{max_value}], result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'step') {
        my $max_check = defined $self->{max_value} ? $value <= ($self->{max_value} // $self->{max}) : 1;
        my $result = ($value >= ($self->{start_value} // 0)) && $max_check && (($value - ($self->{start_value} // 0)) % ($self->{step} // 1) == 0);
        print "DEBUG: Step match for $self->{field_type}, value=$value, start=$self->{start_value}, step=$self->{step}, max=", (defined $self->{max_value} ? $self->{max_value} : 'none'), ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    print "DEBUG: No match for $self->{field_type}, returning 0\n" if $Cron::Describe::Quartz::DEBUG;
    return 0;
}

1;
