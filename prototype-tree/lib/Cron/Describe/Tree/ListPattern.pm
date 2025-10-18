package Cron::Describe::Tree::ListPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Tree::CompositePattern';
use Carp qw(croak);
use Cron::Describe::Tree::Utils qw(join_parts num_to_ordinal);

sub to_english {
    my ($self, $field_type) = @_;
    my @child_descs = map { $_->to_english($field_type) } $self->get_children;
    return join_parts(@child_descs);
}

1;
