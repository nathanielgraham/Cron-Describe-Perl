# File: lib/Cron/Describe/Standard.pm
package Cron::Describe::Standard;
use strict;
use warnings;
use parent 'Cron::Describe::Base';
use Carp qw(croak);

sub new {
    my ($class, %args) = @_;
    $args{type} = 'standard';
    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
