# File: lib/Cron/Describe/ListPattern.pm
package Cron::Describe::ListPattern;
use strict;
use warnings;
use parent 'Cron::Describe::Pattern';

sub new {
    my ($class, $value, $min, $max) = @_;
    my $self = bless {
        pattern_type => 'list',
        min_value => $min,
        max_value => $max,
        raw_value => $value,
        errors => [],
    }, $class;

    my @parts = split /,/, $value;
    my @sub_patterns;
    for my $part (@parts) {
        my $sub = Cron::Describe::Pattern->new($part, $min, $max);
        if ($sub->has_errors) {
            push @{$self->{errors}}, @{ $sub->{errors} };
        } else {
            push @sub_patterns, $sub;
        }
    }
    $self->{sub_patterns} = \@sub_patterns;
    return $self;
}

sub validate {
    my ($self) = @_;
    return ! $self->has_errors;
}

sub is_match {
    my ($self, $value) = @_;
    return 0 if $self->has_errors;
    return grep { $_->is_match($value) } @{$self->{sub_patterns}};
}

sub to_english {
    my ($self) = @_;
    my @descs = map { $_->to_english } @{$self->{sub_patterns}};
    return join(", ", @descs);
}

sub to_string {
    my ($self) = @_;
    return join(",", map { $_->to_string } @{$self->{sub_patterns}});
}

1;
