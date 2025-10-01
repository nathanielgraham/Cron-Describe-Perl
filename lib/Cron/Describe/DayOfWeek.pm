package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use base 'Cron::Describe::Field';

sub parse {
    my $self = shift;
    my $value = $self->{value} // '*';
    if ($value =~ /^(\d+)#(\d+)$/) {
        $self->{parsed} = [{ type => 'nth', day => $1, nth => $2 }];
        die "Invalid nth: $2 (max 5)" if $2 < 1 || $2 > 5;
        die "Invalid day: $1" if $1 < 0 || $1 > 7;
    } elsif ($value =~ /^(\d+)L$/) {
        $self->{parsed} = [{ type => 'last_of_day', day => $1 }];
        die "Invalid day: $1" if $1 < 0 || $1 > 7;
    } else {
        $self->SUPER::parse();
    }
}

sub matches {
    my ($self, $time_parts) = @_;
    my $dow = $time_parts->{dow};
    my $dom = $time_parts->{dom};
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'nth') {
            my $occurrence = int(($dom - 1) / 7) + 1;
            return $dow == $struct->{day} && $occurrence == $struct->{nth};
        } elsif ($struct->{type} eq 'last_of_day') {
            my $occurrence = int(($dom - 1) / 7) + 1;
            my $dim = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
            my $max_occurrence = int(($dim - 1) / 7) + 1;
            return $dow == $struct->{day} && $occurrence == $max_occurrence;
        }
        return $self->SUPER::matches($time_parts);
    }
    return 0;
}

sub to_english {
    my $self = shift;
    my @phrases;
    my %dow_names = (0=>'Sunday', 1=>'Monday', 2=>'Tuesday', 3=>'Wednesday', 4=>'Thursday', 5=>'Friday', 6=>'Saturday', 7=>'Sunday');
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'nth') {
            my $nth = $struct->{nth} == 1 ? 'first' : $struct->{nth} == 2 ? 'second' : $struct->{nth} == 3 ? 'third' : $struct->{nth} == 4 ? 'fourth' : 'fifth';
            push @phrases, "$nth $dow_names{$struct->{day}}";
        } elsif ($struct->{type} eq 'last_of_day') {
            push @phrases, "last $dow_names{$struct->{day}}";
        } else {
            push @phrases, $self->SUPER::to_english();
        }
    }
    return join(', ', @phrases);
}

1;
