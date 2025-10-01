package Cron::Describe;

# ABSTRACT: Parse and describe standard and Quartz cron expressions, validating their syntax and generating human-readable descriptions

use strict;
use warnings;
use POSIX 'mktime';
use Cron::Describe::Field;
use Cron::Describe::DayOfMonth;
use Cron::Describe::DayOfWeek;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    my $expr = $args{expression} // die "No expression provided";
    my @raw_fields = split /\s+/, $expr;
    my @field_types = $self->is_quartz ? qw(seconds minute hour dom month dow year)
                                      : qw(minute hour dom month dow);
    # Allow 6 or 7 fields for Quartz (optional year)
    die "Invalid field count: " . @raw_fields unless @raw_fields == @field_types || ($self->is_quartz && @raw_fields == 6);

    $self->{fields} = [];
    for my $i (0 .. $#raw_fields) {
        my $type = $field_types[$i];
        my $field_class = $type eq 'dom' ? 'Cron::Describe::DayOfMonth'
                        : $type eq 'dow' ? 'Cron::Describe::DayOfWeek'
                        : 'Cron::Describe::Field';
        my $field_args = { type => $type, value => $raw_fields[$i] };
        # Set bounds
        $field_args->{min} = 0; $field_args->{max} = 59 if $type eq 'seconds' || $type eq 'minute';
        $field_args->{min} = 0; $field_args->{max} = 23 if $type eq 'hour';
        $field_args->{min} = 1; $field_args->{max} = 31 if $type eq 'dom';
        $field_args->{min} = 1; $field_args->{max} = 12 if $type eq 'month';
        $field_args->{min} = 0; $field_args->{max} = 7  if $type eq 'dow';
        $field_args->{min} = 1970; $field_args->{max} = 2199 if $type eq 'year';
        push @{$self->{fields}}, $field_class->new(%$field_args);
    }
    return $self;
}

sub is_quartz { 0 }  # Overridden in Quartz.pm

sub is_valid {
    my $self = shift;
    # Syntax and bounds check
    for my $field (@{$self->{fields}}) {
        return 0 unless $field->validate();
    }
    # Heuristic: Can it ever trigger?
    return $self->_can_trigger();
}

sub _can_trigger {
    my $self = shift;
    my $start = time;
    my $max_days = 365 * 2;  # Reduced to 2 years for performance
    for my $i (0 .. $max_days) {
        my $t = $start + $i * 86400;
        my @lt = localtime($t);
        my %time_parts = (
            seconds => $lt[0],
            minute  => $lt[1],
            hour    => $lt[2],
            dom     => $lt[3],
            month   => $lt[4] + 1,
            dow     => $lt[6],
            year    => $lt[5] + 1900,
        );
        my $matches_all = 1;
        for my $field (@{$self->{fields}}) {
            $matches_all = 0 unless $field->matches(\%time_parts);
        }
        return 1 if $matches_all;
    }
    return 0;  # No match found
}

sub describe {
    my $self = shift;
    my @descs = map { $_->to_english() } @{$self->{fields}};
    # Format time fields (seconds, minute, hour) as 0:0:0 if *
    my @time_parts;
    for my $i (0..2) {
        my $desc = $descs[$i] // 'every ' . $self->{fields}[$i]{type};
        $time_parts[$i] = $desc =~ /^every/ ? 0 : $desc;
    }
    my $time = join(':', @time_parts);
    # Format date fields (dom, month, dow, year) with proper names
    my @date_parts;
    for my $i (3..$#descs) {
        my $type = $self->{fields}[$i]{type};
        $type = 'day-of-month' if $type eq 'dom';
        $type = 'day-of-week' if $type eq 'dow';
        my $desc = $descs[$i] // 'every ' . $type;
        $desc =~ s/^every dom/every day-of-month/;
        $desc =~ s/^every dow/every day-of-week/;
        push @date_parts, $desc;
    }
    return "at $time on " . join(', ', @date_parts);
}

sub _days_in_month {
    my ($mon, $year) = @_;
    my @days = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);
    my $d = $days[$mon];
    $d = 29 if $mon == 2 && $year % 4 == 0 && ($year % 100 != 0 || $year % 400 == 0);
    return $d;
}

sub _dow_of_date {
    my ($year, $mon, $dom) = @_;
    my $epoch = mktime(0, 0, 0, $dom, $mon - 1, $year - 1900, 0, 0, -1);
    my @lt = localtime($epoch);
    return $lt[6];
}

1;
