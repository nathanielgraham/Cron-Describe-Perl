# File: lib/Cron/Describe/Quartz.pm
package Cron::Describe::Quartz;
use strict;
use warnings;
use parent 'Cron::Describe::Base';
use Carp qw(croak);

our $DEBUG = $ENV{CRON_DESCRIBE_DEBUG} // 1;  # Enable debug by default or via env

sub new {
    my ($class, %args) = @_;
    $args{type} = 'quartz';
    my $self = $class->SUPER::new(%args);
    return $self;
}

1;
