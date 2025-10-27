package Cron::Toolkit::Pattern::SinglePattern;
use strict;
use warnings;
use parent 'Cron::Toolkit::Pattern::LeafPattern';
use Cron::Toolkit::Utils qw(:all);

sub to_english {
    my ($self, $field_type) = @_;
    my $value = $self->{value};
    if ($field_type eq 'dom') {
        return num_to_ordinal($value);
    } elsif ($field_type eq 'dow') {
        return $day_names{$value} || $value;
    } else {
        return $value;  # PLAIN for minute/hour/year/second
    }
}

1;
