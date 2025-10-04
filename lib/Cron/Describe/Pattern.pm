# File: lib/Cron/Describe/Pattern.pm
package Cron::Describe::Pattern;
use strict;
use warnings;
use Carp qw(croak);

sub new {
    my ($class, $value, $min, $max) = @_;
    croak "Value is required" unless defined $value;
    croak "Min and max are required" unless defined $min && defined $max;

    my $pattern_type = _detect_pattern_type($value);
    my $pattern_class = $pattern_type eq 'wildcard' ? 'Cron::Describe::WildcardPattern' :
                       $pattern_type eq 'unspecified' ? 'Cron::Describe::UnspecifiedPattern' :
                       $pattern_type eq 'single' ? 'Cron::Describe::SinglePattern' :
                       $pattern_type eq 'range' ? 'Cron::Describe::RangePattern' :
                       $pattern_type eq 'step' ? 'Cron::Describe::StepPattern' :
                       $pattern_type eq 'list' ? 'Cron::Describe::ListPattern' :
                       'Cron::Describe::Pattern'; # Fallback for special patterns

    eval "require $pattern_class";
    croak "Failed to load $pattern_class: $@" if $@;

    return $pattern_class->new($value, $min, $max);
}

sub _detect_pattern_type {
    my ($value) = @_;
    return 'wildcard' if $value eq '*';
    return 'unspecified' if $value eq '?';
    return 'list' if $value =~ /,/;
    return 'step' if $value =~ m{/.+};
    return 'range' if $value =~ m{^\d+-\d+$};
    return 'single' if $value =~ m{^\d+$};
    return 'special'; # Handled by subclasses
}

sub validate { croak "Abstract method validate not implemented"; }
sub is_match { croak "Abstract method is_match not implemented"; }
sub to_english { croak "Abstract method to_english not implemented"; }
sub to_string { croak "Abstract method to_string not implemented"; }

sub has_errors {
    my ($self) = @_;
    return @{$self->{errors} || []};
}

1;
