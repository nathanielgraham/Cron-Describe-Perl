package Cron::Toolkit::Pattern::ListPattern;
use strict;
use warnings;
use parent 'Cron::Toolkit::Pattern::CompositePattern';
use Carp qw(croak);
use Cron::Toolkit::Utils qw(:all);

sub to_english {
    my ($self, $field_type) = @_;
    my @child_descs = map { $_->to_english($field_type) } $self->get_children;
    return join_parts(@child_descs);
}

1;
