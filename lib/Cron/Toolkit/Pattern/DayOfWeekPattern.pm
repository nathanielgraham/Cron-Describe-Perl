package Cron::Toolkit::Pattern::DayOfWeekPattern;
use strict;
use warnings;
use parent 'Cron::Toolkit::Pattern::LeafPattern';
use Carp qw(croak);
use Cron::Toolkit::Utils qw(:all);

sub to_english {
    my ($self) = @_;
    if ($self->{type} eq 'nth') {
        my ($day, $nth) = $self->{value} =~ /(\d+)#(\d+)/;
        return num_to_ordinal($nth) . " " . $day_names[$day] . " of every month";
    } elsif ($self->{type} eq 'single') {
        return "every " . $day_names[$self->{value}];
    }
    return $self->SUPER::to_english();
}

1;
