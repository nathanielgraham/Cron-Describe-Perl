package Cron::Describe::DayOfMonth;

use strict;
use warnings;
use base 'Cron::Describe::Field';

sub parse {
    my $self = shift;
    my $value = $self->{value} // '*';
    if ($value =~ /^L(?:-(\d+))?$/) {
        $self->{parsed} = [{ type => 'last', offset => $1 // 0 }];
        die "Invalid offset: $1" if defined $1 && $1 > 30;
    } elsif ($value =~ /^(\d+)W$/) {
        $self->{parsed} = [{ type => 'nearest_weekday', day => $1 }];
        die "Invalid day: $1" if $1 < 1 || $1 > 31;
    } else {
        $self->SUPER::parse();
    }
}

sub matches {
    my ($self, $time_parts) = @_;
    my $dom = $time_parts->{dom};
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'last') {
            my $last_day = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
            return $dom == $last_day - $struct->{offset};
        } elsif ($struct->{type} eq 'nearest_weekday') {
            my $target_day = $struct->{day};
            my $dow = Cron::Describe::_dow_of_date($time_parts->{year}, $time_parts->{month}, $target_day);
            if ($dow == 6) { $target_day -= 1; }  # Sat -> Fri
            elsif ($dow == 0) { $target_day += 1; }  # Sun -> Mon
            my $dim = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
            return 0 if $target_day < 1 || $target_day > $dim;
            return $dom == $target_day;
        }
        return $self->SUPER::matches($time_parts);
    }
    return 0;
}

sub to_english {
    my $self = shift;
    my @phrases;
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'last') {
            push @phrases, $struct->{offset} ? "last day minus $struct->{offset}" : "last day";
        } elsif ($struct->{type} eq 'nearest_weekday') {
            push @phrases, "nearest weekday to the $struct->{day}";
        } else {
            push @phrases, $self->SUPER::to_english();
        }
    }
    return join(', ', @phrases);
}

1;
