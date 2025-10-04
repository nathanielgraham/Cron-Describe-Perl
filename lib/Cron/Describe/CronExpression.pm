package Cron::Describe::CronExpression;
use strict;
use warnings;
use Carp;
use Cron::Describe::SinglePattern;
use Cron::Describe::WildcardPattern;
use Cron::Describe::UnspecifiedPattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;
use Cron::Describe::ListPattern;
use Cron::Describe::DayOfMonthPattern;
use Cron::Describe::DayOfWeekPattern;

sub new {
    my ($class, $expression) = @_;
    croak "Expression required" unless defined $expression;

    my @parts = split /\s+/, $expression;
    my $type = (@parts == 5) ? 'standard' : (@parts == 6 || @parts == 7) ? 'quartz' : croak "Invalid field count: " . @parts;

    my @field_types = $type eq 'quartz'
        ? qw(second minute hour day_of_month month day_of_week year)
        : qw(minute hour day_of_month month day_of_week);

    if ($type eq 'quartz' && @parts == 6) {
        push @parts, '*';
    }

    croak "Field count mismatch: got " . @parts . ", expected " . @field_types
        unless @parts == @field_types;

    my %ranges = (
        second      => [0, 59],
        minute      => [0, 59],
        hour        => [0, 23],
        day_of_month => [1, 31],
        month       => [1, 12],
        day_of_week => [0, 7],
        year        => [1970, 2099],
    );

    my @fields;
    for my $i (0 .. $#parts) {
        my $value = $parts[$i];
        my $field_type = $field_types[$i];
        my ($min, $max) = @{$ranges{$field_type} || croak "Unknown field type: $field_type"};
        my $pattern;

        if ($value eq '*') {
            $pattern = Cron::Describe::WildcardPattern->new($value, $min, $max, $field_type);
        }
        elsif ($value eq '?') {
            $pattern = Cron::Describe::UnspecifiedPattern->new($value, $min, $max, $field_type);
        }
        elsif ($value =~ /^(\d+)-(\d+)\/(\d+)$/) {
            $pattern = Cron::Describe::StepPattern->new($value, $min, $max, $field_type);
        }
        elsif ($value =~ /^(\d+)-(\d+)$/) {
            $pattern = Cron::Describe::RangePattern->new($value, $min, $max, $field_type);
        }
        elsif ($value =~ /,/) {
            $pattern = Cron::Describe::ListPattern->new($value, $min, $max, $field_type);
        }
        elsif ($value =~ /^[LW#]/ || $value =~ /L-\d+$/) {
            $pattern = $field_type eq 'day_of_month'
                ? Cron::Describe::DayOfMonthPattern->new($value, $min, $max, $field_type)
                : Cron::Describe::DayOfWeekPattern->new($value, $min, $max, $field_type);
        }
        else {
            $pattern = Cron::Describe::SinglePattern->new($value, $min, $max, $field_type);
        }
        push @fields, $pattern;
    }

    my $self = bless { expression => $expression, type => $type, fields => \@fields }, $class;
    $self->validate;
    return $self;
}

sub validate {
    my ($self) = @_;
    for my $i (0 .. $#{$self->{fields}}) {
        my $field = $self->{fields}[$i];
        if ($field->has_errors) {
            croak "Validation failed for field $i ($field->{field_type}): " . join(", ", @{$field->{errors}});
        }
    }
    if ($self->{type} eq 'quartz') {
        my $dom = $self->{fields}[3];
        my $dow = $self->{fields}[5];
        if (!$dom->isa('Cron::Describe::UnspecifiedPattern') && !$dow->isa('Cron::Describe::UnspecifiedPattern')) {
            croak "Quartz: day_of_month and day_of_week cannot both be specific";
        }
    }
    return 1;
}

sub is_match {
    my ($self, $tm) = @_;
    croak "Time::Moment object required" unless $tm->isa('Time::Moment');
    for my $field (@{$self->{fields}}) {
        my $field_type = $field->{field_type};
        my %field_map = (
            second      => 'second',
            minute      => 'minute',
            hour        => 'hour',
            day_of_month => 'day_of_month',
            month       => 'month',
            day_of_week => 'day_of_week',
            year        => 'year',
        );
        my $method = $field_map{$field_type} or croak "Unknown field type: $field_type";
        return 0 unless $field->is_match($tm->$method());
    }
    return 1;
}

sub to_english {
    my ($self) = @_;
    return join ' ', map { $_->to_english } @{$self->{fields}};
}

sub to_string {
    my ($self) = @_;
    return $self->{expression};
}

1;
