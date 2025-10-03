package Cron::Describe::Quartz;
use strict;
use warnings;
use parent 'Cron::Describe::Base';

sub new {
    my ($class, %args) = @_;
    $args{type} = 'quartz';
    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
