package Cron::Describe::ListPattern;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;
use parent 'Cron::Describe::Pattern';
use Cron::Describe::Utils qw(:all);

sub to_english {
    my ($self, $field_type) = @_;
    my @values = map { $_->{value} } @{$self->{patterns}};
    if ($field_type eq 'dow') {
        return join_parts(map { $day_names[$_] } @values);
    }
    return join_parts(map { num_to_ordinal($_) } @values);
}

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: Cron::Describe::ListPattern: ListPattern::new: value='$value', field_type='$field_type', min=$min, max=$max\n" if $ENV{Cron_DEBUG};
    my @sub_patterns = split /,/, $value;
    croak "Empty list pattern for $field_type" unless @sub_patterns;

    my @patterns;
    for my $sub_pattern (@sub_patterns) {
        $sub_pattern =~ s/^\s+|\s+$//g; # Trim whitespace
        print STDERR "DEBUG: Cron::Describe::ListPattern: parsing sub-pattern '$sub_pattern'\n" if $ENV{Cron_DEBUG};
        my $pattern;
        eval {
            if ($sub_pattern =~ /^\d+$/) {
                print STDERR "DEBUG: trying SinglePattern for '$sub_pattern'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::SinglePattern->new($sub_pattern, $min, $max, $field_type);
            } elsif ($sub_pattern =~ /^(\d+)-(\d+)$/) {
                print STDERR "DEBUG: trying RangePattern for '$sub_pattern'\n" if $ENV{Cron_DEBUG};
                my ($start, $end) = ($1, $2);
                croak "Range start $start exceeds end $end in '$sub_pattern' for $field_type" if $start > $end;
                croak "Range start $start below min $min in '$sub_pattern' for $field_type" if $start < $min;
                croak "Range end $end above max $max in '$sub_pattern' for $field_type" if $end > $max;
                $pattern = Cron::Describe::RangePattern->new($sub_pattern, $min, $max, $field_type);
            } elsif ($sub_pattern =~ /^(\*|\d+|\d+-\d+)\/(\d+)$/) {
                print STDERR "DEBUG: trying StepPattern for '$sub_pattern'\n" if $ENV{Cron_DEBUG};
                my $step = $2;
                croak "Step value $step must be positive in '$sub_pattern' for $field_type" if $step <= 0;
                $pattern = Cron::Describe::StepPattern->new($sub_pattern, $min, $max, $field_type);
            } else {
                croak "Invalid sub-pattern '$sub_pattern' in list for $field_type";
            }
            push @patterns, $pattern;
            print STDERR "DEBUG: Cron::Describe::ListPattern: added sub-pattern " . ref($pattern) . " for '$sub_pattern'\n" if $ENV{Cron_DEBUG};
        };
        if ($@) {
            print STDERR "DEBUG: Cron::Describe::ListPattern: error parsing sub-pattern '$sub_pattern': $@\n" if $ENV{Cron_DEBUG};
            croak "Invalid sub-pattern '$sub_pattern' in list for $field_type: $@";
        }
    }

    my $self = bless {
        value => $value,
        min => $min,
        max => $max,
        pattern_type => 'list',
        field_type => $field_type,
        patterns => \@patterns,
    }, $class;
    return $self;
}

sub to_hash {
    my ($self) = @_;
    return {
        field_type => $self->{field_type},
        pattern_type => 'list',
        min => $self->{min},
        max => $self->{max},
        step => 1, # Added for consistency with other patterns
        patterns => [ map { $_->to_hash } @{$self->{patterns}} ],
    };
}

sub to_string {
    my ($self) = @_;
    return $self->{value};
}

sub is_match {
    my ($self, $value, $tm) = @_;
    print STDERR "DEBUG: is_match: ListPattern: value=$value, pattern_value=$self->{value}\n" if $ENV{Cron_DEBUG};
    for my $pattern (@{$self->{patterns}}) {
        print STDERR "DEBUG: is_match: checking sub-pattern " . ref($pattern) . " with value=$value\n" if $ENV{Cron_DEBUG};
        return 1 if $pattern->is_match($value, $tm);
    }
    return 0;
}

1;
