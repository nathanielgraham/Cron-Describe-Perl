# File: lib/Cron/Describe/Pattern.pm
package Cron::Describe::Pattern;
use strict;
use warnings;
use Carp qw(croak);

sub validate { croak "Abstract method validate not implemented"; }
sub is_match { croak "Abstract method is_match not implemented"; }
sub to_english { croak "Abstract method to_english not implemented"; }
sub to_string { croak "Abstract method to_string not implemented"; }

sub has_errors {
    my ($self) = @_;
    return @{$self->{errors} || []} > 0;
}

1;
