# File: lib/Cron/Describe/Field.pm
package Cron::Describe::Field;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, %args) = @_;
    croak("field_type required") unless defined $args{field_type};
    croak("range required for $args{field_type}") unless defined $args{range} && ref($args{range}) eq 'ARRAY';
    croak("min required for $args{field_type}") unless defined $args{range}[0];
    croak("max required for $args{field_type}") unless defined $args{range}[1];
    my $self = bless {
        field_type   => $args{field_type},
        min          => $args{range}[0],
        max          => $args{range}[1],
        value        => $args{value},
        pattern_type => undef,
        step         => 1,  # Default for test compatibility
    }, $class;
    print "DEBUG: Creating Field object for $args{field_type}, range=[$args{range}[0],$args{range}[1]], value=", (defined $args{value} ? "'$args{value}'" : 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    $self->parse($args{value}) if defined $args{value};
    return $self;
}

sub parse {
    my ($self, $value) = @_;
    print "DEBUG: Parsing $self->{field_type} with value ", (defined $value ? "'$value'" : 'undef'), ", caller=", (caller(1))[3] || 'unknown', "\n" if $Cron::Describe::Quartz::DEBUG;

    unless (defined $value && $value ne '') {
        $self->{pattern_type} = 'error';
        $self->{error} = "Undefined or empty value for $self->{field_type}";
        print "DEBUG: No pattern matched for $self->{field_type} with undefined or empty value, marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }

    if ($value eq '*') {
        $self->{pattern_type} = 'wildcard';
        $self->{min_value} = $self->{min};
        $self->{max_value} = $self->{max};
        $self->{step} = 1;
        print "DEBUG: Matched wildcard for $self->{field_type}\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    elsif ($value eq '?') {
        $self->{pattern_type} = 'unspecified';
        print "DEBUG: Matched unspecified for $self->{field_type}\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }

    my @parts = split /,/, $value;
    if (@parts > 1) {
        my @sub_patterns;
        for my $part (@parts) {
            print "DEBUG: Parsing list part '$part' for $self->{field_type}\n" if $Cron::Describe::Quartz::DEBUG;
            my $sub = $self->parse_item($part);
            if ($sub->{pattern_type} eq 'error') {
                $self->{pattern_type} = 'error';
                $self->{error} = $sub->{error};
                print "DEBUG: No pattern matched for $self->{field_type} list part '$part', marking as error\n" if $Cron::Describe::Quartz::DEBUG;
                return;
            }
            push @sub_patterns, $sub;
        }
        $self->{pattern_type} = 'list';
        $self->{sub_patterns} = \@sub_patterns;
        print "DEBUG: Matched list for $self->{field_type}, sub_patterns count=", scalar(@sub_patterns), "\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }

    my $result = $self->parse_item($value);
    if ($result->{pattern_type} eq 'error') {
        $self->{pattern_type} = 'error';
        $self->{error} = $result->{error};
        print "DEBUG: No pattern matched for $self->{field_type} with value '$value', marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    %$self = (%$self, %$result);
}

sub parse_item {
    my ($self, $item) = @_;
    my $result = { step => 1, min => $self->{min}, max => $self->{max} };

    if ($item =~ /^(.+)\/(\d+)$/) {
        my ($base, $step) = ($1, $2);
        if ($step <= 0) {
            return { pattern_type => 'error', error => "Step must be >0 in $self->{field_type}" };
        }
        my $base_parsed = $self->parse_base($base);
        if ($base_parsed->{pattern_type} eq 'error') {
            return $base_parsed;
        }
        $result->{pattern_type} = 'step';
        $result->{base} = $base_parsed;
        $result->{step} = $step + 0;
        $result->{start_value} = $base_parsed->{min_value} // $self->{min};
        $result->{min_value} = $base_parsed->{min_value} // $self->{min};
        $result->{max_value} = $base_parsed->{max_value} // $self->{max};
        print "DEBUG: Matched step for $self->{field_type}, base_type=$base_parsed->{pattern_type}, step=$step\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    return $self->parse_base($item);
}

sub parse_base {
    my ($self, $base) = @_;
    my $result = { step => 1, min => $self->{min}, max => $self->{max} };

    if ($base =~ /^(\d+)-(\d+)$/) {
        my ($min_val, $max_val) = ($1 + 0, $2 + 0);
        if ($min_val > $max_val || $min_val < $self->{min} || $max_val > $self->{max}) {
            return { pattern_type => 'error', error => "Invalid range $min_val-$max_val for $self->{field_type}" };
        }
        $result->{pattern_type} = 'range';
        $result->{min} = $min_val;
        $result->{max} = $max_val;
        $result->{min_value} = $min_val;
        $result->{max_value} = $max_val;
        print "DEBUG: Matched range for $self->{field_type}, min=$min_val, max=$max_val\n" if $Cron::Describe::Quartz::DEBUG;
    }
    elsif ($base =~ /^\d+$/) {
        my $val = $base + 0;
        if ($val < $self->{min} || $val > $self->{max}) {
            return { pattern_type => 'error', error => "Value $val out of range [$self->{min}-$self->{max}] for $self->{field_type}" };
        }
        $result->{pattern_type} = 'single';
        $result->{value} = $val;
        $result->{min_value} = $val;
        $result->{max_value} = $val;
        print "DEBUG: Matched single for $self->{field_type}, value=$val\n" if $Cron::Describe::Quartz::DEBUG;
    }
    else {
        return { pattern_type => 'error', error => "Unknown pattern '$base' for $self->{field_type}" };
    }
    return $result;
}

sub to_english {
    my ($self) = @_;
    my $type = $self->{pattern_type} || 'error';
    print "DEBUG: to_english for $self->{field_type}, pattern_type=$type\n" if $Cron::Describe::Quartz::DEBUG;

    if ($type eq 'wildcard') {
        return $self->{field_type} eq 'dom' ? "every day of month" : 
               $self->{field_type} eq 'dow' ? "every day-of-week" :
               $self->{field_type} eq 'month' ? "every month" :
               "every $self->{field_type}";
    }
    elsif ($type eq 'unspecified') {
        return $self->{field_type} eq 'dow' ? "any day-of-week" : "any $self->{field_type}";
    }
    elsif ($type eq 'single') {
        return $self->{field_type} eq 'dom' ? "on day $self->{value} of month" :
               $self->{field_type} eq 'month' ? "in month $self->{value}" :
               "at $self->{field_type} $self->{value}";
    }
    elsif ($type eq 'range') {
        return $self->{field_type} eq 'dom' ? "on days $self->{min} to $self->{max} of month" :
               $self->{field_type} eq 'month' ? "in months $self->{min} to $self->{max}" :
               "from $self->{min} to $self->{max} $self->{field_type}";
    }
    elsif ($type eq 'step') {
        my $base_desc = $self->{base}{pattern_type} eq 'range'
            ? "from $self->{base}{min} to $self->{base}{max}"
            : "every $self->{field_type}";
        return $self->{field_type} eq 'dom' ? "every $self->{step} days $base_desc of month" :
               $self->{field_type} eq 'month' ? "every $self->{step} months $base_desc" :
               "every $self->{step} $self->{field_type} $base_desc";
    }
    elsif ($type eq 'list') {
        my @descs = map { $self->sub_to_english($_) } @{$self->{sub_patterns}};
        return $self->{field_type} eq 'dom' ? "on " . join(", ", @descs) . " of month" :
               $self->{field_type} eq 'dow' ? "on " . join(", ", @descs) :
               join(", ", @descs);
    }
    return "invalid $self->{field_type}";
}

sub sub_to_english {
    my ($self, $sub) = @_;
    if ($sub->{pattern_type} eq 'range') {
        return $self->{field_type} eq 'dom' ? "days $sub->{min} to $sub->{max}" :
               $self->{field_type} eq 'month' ? "months $sub->{min} to $sub->{max}" :
               "from $sub->{min} to $sub->{max} $self->{field_type}";
    }
    elsif ($sub->{pattern_type} eq 'step') {
        my $base_desc = $sub->{base}{pattern_type} eq 'range'
            ? "from $sub->{base}{min} to $sub->{base}{max}"
            : "every $self->{field_type}";
        return $self->{field_type} eq 'dom' ? "every $sub->{step} days $base_desc" :
               $self->{field_type} eq 'month' ? "every $sub->{step} months $base_desc" :
               "every $sub->{step} $self->{field_type} $base_desc";
    }
    elsif ($sub->{pattern_type} eq 'single') {
        return $self->{field_type} eq 'dom' ? "day $sub->{value}" :
               $self->{field_type} eq 'month' ? "month $sub->{value}" :
               "at $self->{field_type} $sub->{value}";
    }
    return "invalid $self->{field_type}";
}

sub is_match {
    my ($self, $date) = @_;
    my $type = $self->{pattern_type} || 'error';
    print "DEBUG: is_match for $self->{field_type}, pattern_type=$type\n" if $Cron::Describe::Quartz::DEBUG;
    return 0 if $type eq 'error';

    my $value = $self->_get_date_value($date);
    if ($type eq 'wildcard' || $type eq 'unspecified') {
        return 1;
    }
    elsif ($type eq 'single') {
        return $value == $self->{value};
    }
    elsif ($type eq 'range') {
        return $value >= $self->{min} && $value <= $self->{max};
    }
    elsif ($type eq 'step') {
        my $start = $self->{base}{min} // $self->{min};
        return 0 unless $value >= $start && $value <= $self->{max};
        return ($value - $start) % $self->{step} == 0;
    }
    elsif ($type eq 'list') {
        for my $sub (@{$self->{sub_patterns}}) {
            return 1 if $self->_sub_match($sub, $value);
        }
        return 0;
    }
    return 0;
}

sub _sub_match {
    my ($self, $sub, $value) = @_;
    if ($sub->{pattern_type} eq 'single') {
        return $value == $sub->{value};
    }
    elsif ($sub->{pattern_type} eq 'range') {
        return $value >= $sub->{min} && $value <= $sub->{max};
    }
    elsif ($sub->{pattern_type} eq 'step') {
        my $start = $sub->{base}{min} // $self->{min};
        return 0 unless $value >= $start && $value <= $sub->{max};
        return ($value - $start) % $sub->{step} == 0;
    }
    return 0;
}

sub _get_date_value {
    my ($self, $date) = @_;
    my $type = $self->{field_type};
    return $type eq 'seconds' ? $date->second :
           $type eq 'minute' ? $date->minute :
           $type eq 'hour' ? $date->hour :
           $type eq 'dom' ? $date->day_of_month :
           $type eq 'month' ? $date->month :
           $type eq 'dow' ? $date->day_of_week % 7 :
           $type eq 'year' ? $date->year : 0;
}

1;
