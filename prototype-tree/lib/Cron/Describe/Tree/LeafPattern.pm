package Cron::Describe::Tree::LeafPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Tree::Pattern';
use Carp qw(croak);

sub new {
    my ($class, %args) = @_;
    my $self = $class->SUPER::new(%args);
    $self->{value} = $args{value} // croak "value required";
    return $self;
}
1;
