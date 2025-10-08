package Cron::Describe::ListPattern;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: ListPattern::new: value='$value', field_type='$field_type'\n";
    my @values = split /,/, $value;
    my $self = bless {}, $class;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;
    $self->{sub_patterns} = [];

    foreach my $val (@values) {
        print STDERR "DEBUG: ListPattern: parsing sub-pattern '$val'\n";
        my $pattern;
        if ($val eq '*') {
            $pattern = Cron::Describe::WildcardPattern->new($val, $min, $max, $field_type);
        } elsif ($val =~ /^\d+$/) {
            $pattern = Cron::Describe::SinglePattern->new($val, $min, $max, $field_type);
        } elsif ($val =~ /^(\d+)-(\d+)$/) {
            $pattern = Cron::Describe::RangePattern->new($val, $min, $max, $field_type);
        } elsif ($val =~ /^(\*|\d+|\d+-\d+)\/\d+$/) {
            $pattern = Cron::Describe::StepPattern->new($val, $min, $max, $field_type);
        } else {
            croak "Invalid list element '$val' for $field_type";
        }
        push @{$self->{sub_patterns}}, $pattern;
        print STDERR "DEBUG: ListPattern: added sub-pattern " . ref($pattern) . "\n";
    }

    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    foreach my $pattern (@{$self->{sub_patterns}}) {
        return 1 if $pattern->is_match($value, $tm);
    }
    return 0;
}

sub to_hash {
    my $self = shift;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => 'list',
        min => $self->{min},
        max => $self->{max},
        step => 1,
        sub_patterns => [ map { my $h = $_->to_hash; $h->{field_type} = $self->{field_type}; $h } @{$self->{sub_patterns}} ]
    };
    print STDERR "DEBUG: ListPattern::to_hash: " . join(", ", map { "$_=$hash->{$_}" } keys %$hash) . "\n";
    return $hash;
}

1;
