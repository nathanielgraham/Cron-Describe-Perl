package Cron::Describe::Quartz;
use strict;
use warnings;
use base 'Cron::Describe';
sub new {
    my ($class, %args) = @_;
    print STDERR "DEBUG: Quartz.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n";
    my $self = $class->SUPER::new(%args);
    $self->{expression_type} = 'quartz';
    return $self;
}
sub is_quartz {
    my $self = shift;
    return 1;
}
# No override for to_english - use centralized in Describe.pm
1;
