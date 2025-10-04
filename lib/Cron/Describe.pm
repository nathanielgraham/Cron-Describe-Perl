# File: lib/Cron/Describe.pm
package Cron::Describe;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::Quartz;
use Cron::Describe::Standard;

sub new {
    my ($class, %args) = @_;
    my $expression = $args{expression} or croak "Expression is required";
    
    # Normalize expression by trimming whitespace
    $expression =~ s/^\s+|\s+$//g;
    
    # Split into fields to determine type
    my @fields = split /\s+/, $expression;
    my $field_count = @fields;
    
    # Quartz: 6-7 fields, Standard: 5-6 fields
    my $type = ($field_count >= 6) ? 'Cron::Describe::Quartz' : 'Cron::Describe::Standard';
    
    # Instantiate the appropriate class
    return $type->new(%args);
}

1;
