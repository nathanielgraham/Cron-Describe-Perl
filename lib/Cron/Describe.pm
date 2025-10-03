package Cron::Describe;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, %args) = @_;
    my $expression = $args{expression} or croak "Expression is required";
    
    # Normalize expression for auto-detection
    $expression =~ s/^\s+|\s+$//g;
    my @fields = split /\s+/, $expression;
    my $has_quartz_tokens = $expression =~ /[?L#W]/;
    
    # Auto-detection logic
    if (@fields == 5 && !$has_quartz_tokens) {
        require Cron::Describe::Standard;
        return Cron::Describe::Standard->new(%args, type => 'standard');
    } elsif (@fields == 5 && $has_quartz_tokens) {
        croak "Invalid 5-field expression with Quartz-specific tokens: '$expression'";
    } else {
        require Cron::Describe::Quartz;
        return Cron::Describe::Quartz->new(%args, type => 'quartz');
    }
}

1;
