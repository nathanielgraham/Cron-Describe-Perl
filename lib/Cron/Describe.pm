package Cron::Describe;
use strict;
use warnings;
use parent 'Cron::Describe::Base';

# ABSTRACT: Entry point for Cron::Describe, delegating to Standard or Quartz subclasses

sub new {
    my ($class, %args) = @_;
    my $expr = $args{expression} // die "No expression provided";
    # Delegate to Standard or Quartz based on field count
    my @fields = split /\s+/, $expr;
    my $subclass = (@fields == 6 || @fields == 7) ? 'Cron::Describe::Quartz' : 'Cron::Describe::Standard';
    return $subclass->new(%args);
}

1;
