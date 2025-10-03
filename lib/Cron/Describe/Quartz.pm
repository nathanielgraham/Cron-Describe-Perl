package Cron::Describe::Quartz;
use strict;
use warnings;
use parent 'Cron::Describe';
BEGIN {
    require Cron::Describe;
    print STDERR "DEBUG: Cron::Describe loaded (mtime: " . (stat($INC{'Cron/Describe.pm'}))[9] . ")\n";
    print STDERR "DEBUG: Checking for is_match in Cron::Describe: " . (Cron::Describe->can('is_match') ? 'Found' : 'Not found') . "\n";
}
sub new {
    my ($class, %args) = @_;
    print STDERR "DEBUG: Quartz.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n";
    my $self = $class->SUPER::new(%args);
    $self->{expression_type} = 'quartz';
    print STDERR "DEBUG: Checking for is_match in self: " . ($self->can('is_match') ? 'Found' : 'Not found') . "\n";
    return $self;
}
sub is_quartz {
    my $self = shift;
    return 1;
}
1;

