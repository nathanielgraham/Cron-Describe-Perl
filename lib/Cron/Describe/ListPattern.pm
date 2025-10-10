package Cron::Describe::ListPattern;
use strict;
use warnings;
use Carp qw(croak);
use parent 'Cron::Describe::Pattern';
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: ListPattern::new: value='$value', field_type='$field_type'\n" if $Cron::Describe::DEBUG;
    my $self = $class->SUPER::new($value, $min, $max, $field_type);
    $self->{pattern_type} = 'list';
    $self->{sub_patterns} = [];
    my @values = split /,/, $value;
    foreach my $val (@values) {
        print STDERR "DEBUG: parsing sub-pattern '$val'\n" if $Cron::Describe::DEBUG;
        my $pattern;
        eval {
            if ($val eq '*') {
                $pattern = Cron::Describe::WildcardPattern->new($val, $min, $max, $field_type);
            } elsif ($val =~ /^\d+$/) {
                $pattern = Cron::Describe::SinglePattern->new($val, $min, $max, $field_type);
            } elsif ($val =~ /^(\d+)-(\d+)$/) {
                $pattern = Cron::Describe::RangePattern->new($val, $min, $max, $field_type);
            } elsif ($val =~ /^(\*|\d+|\d+-\d+)\/\d+$/) {
                $pattern = Cron::Describe::StepPattern->new($val, $min, $max, $field_type);
            } else {
                $self->add_error("Invalid list element '$val' for $field_type");
                croak $self->errors->[0];
            }
        };
        if ($@) {
            $self->add_error("Failed to parse list element '$val': $@");
            croak $self->errors->[0];
        }
        push @{$self->{sub_patterns}}, $pattern;
        print STDERR "DEBUG: added sub-pattern " . ref($pattern) . "\n" if $Cron::Describe::DEBUG;
    }
    $self->validate();
    return $self;
}

sub validate {
    my ($self) = @_;
    foreach my $pattern (@{$self->{sub_patterns}}) {
        $pattern->validate();
    }
    croak join("; ", @{$self->errors}) if $self->has_errors;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $result = 0;
    foreach my $pattern (@{$self->{sub_patterns}}) {
        if ($pattern->is_match($value, $tm)) {
            $result = 1;
            last;
        }
    }
    $self->_debug("is_match: value=$value, sub_patterns=" . scalar(@{$self->{sub_patterns}}) . ", result=$result");
    return $result;
}

sub to_hash {
    my ($self) = shift;
    my $hash = $self->SUPER::to_hash;
    $hash->{sub_patterns} = [ map { $_->to_hash } @{$self->{sub_patterns}} ];
    return $hash;
}

sub to_string {
    my ($self) = @_;
    return join(',', map { $_->to_string } @{$self->{sub_patterns}});
}

sub to_english {
    my ($self) = @_;
    my @descs = map { $_->to_english } @{$self->{sub_patterns}};
    return join(" or ", @descs);
}

1;
