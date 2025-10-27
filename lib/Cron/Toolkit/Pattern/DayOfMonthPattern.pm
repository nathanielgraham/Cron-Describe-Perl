package Cron::Toolkit::Pattern::DayOfMonthPattern;
use strict;
use warnings;
use parent 'Cron::Toolkit::Pattern::LeafPattern';
use Carp qw(croak);
use Cron::Toolkit::Utils qw(:all);

sub to_english {
    my ($self, $is_midnight) = @_;
    if ($self->{type} eq 'last_weekday') {
        return $is_midnight ? 'last weekday of the month' : 'last weekday of every month';
    } elsif ($self->{type} eq 'last' && $self->{value} eq 'L') {
        return $is_midnight ? 'last day of the month' : 'last day of every month';
    } elsif ($self->{type} eq 'last' && $self->{value} =~ /L-(\d+)/) {
        return num_to_ordinal($1) . " last day of every month";
    } elsif ($self->{type} eq 'nearest_weekday') {
        my ($day) = $self->{value} =~ /(\d+)W/;
        return "nearest weekday to the " . num_to_ordinal($day) . " of the month";
    }
    return $self->SUPER::to_english($is_midnight);
}

1;
