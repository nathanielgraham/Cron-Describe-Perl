package Cron::Describe::Standard;

use strict;
use warnings;
use base 'Cron::Describe';

sub new {
    my ($class, %args) = @_;
    print STDERR "DEBUG: Standard.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n";
    my $self = $class->SUPER::new(%args);
    $self->{expression_type} = 'standard';
    return $self;
}

sub is_quartz {
    my $self = shift;
    print STDERR "DEBUG: Standard.pm is_quartz called\n";
    return 0;
}

1;
