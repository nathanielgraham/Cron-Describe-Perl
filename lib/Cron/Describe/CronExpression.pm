# File: lib/Cron/Describe/CronExpression.pm
package Cron::Describe::CronExpression;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;

sub new {
    my ($class, $expression, $type) = @_;
    croak "Expression is required" unless defined $expression;

    my $self = bless {
        expression => $expression,
        type => $type,
        fields => {},
        errors => [],
    }, $class;

    $self->_parse();
    return $self;
}

sub _parse {
    my ($self) = @_;
    my $expression = $self->{expression};
    $expression =~ s/^\s+|\s+$//g;

    my @fields = split /\s+/, $expression;
    my @standard_fields = qw(minute hour dom month dow year);
    my @quartz_fields = qw(seconds minute hour dom month dow year);

    # Auto-detect type if not provided
    unless ($self->{type}) {
        my $field_count = scalar @fields;
        my $has_question_mark = grep { $_ eq '?' } @fields;
        if ($field_count == 5 || ($field_count == 6 && !$has_question_mark)) {
            $self->{type} = 'standard';
        } elsif ($field_count == 6 || $field_count == 7 || $has_question_mark) {
            $self->{type} = 'quartz';
        } else {
            push @{$self->{errors}}, "Cannot auto-detect type: invalid field count ($field_count)";
            return;
        }
    }

    my @field_types = $self->{type} eq 'quartz' ? @quartz_fields : @standard_fields;
    my $min_fields = $self->{type} eq 'quartz' ? 6 : 5;
    my $max_fields = $self->{type} eq 'quartz' ? 7 : 6;

    if (@fields < $min_fields || @fields > $max_fields) {
        push @{$self->{errors}}, "Invalid field count: got " . scalar(@fields) . ", expected $min_fields-$max_fields";
        return;
    }

    my %ranges = (
        seconds => [0, 59],
        minute => [0, 59],
        hour => [0, 23],
        dom => [1, 31],
        month => [1, 12],
        dow => [0, 7],
        year => [1970, 2199],
    );

    for my $i (0 .. $#fields) {
        my $field_type = $field_types[$i] || 'year';
        my $value = $fields[$i];
        my $range = $ranges{$field_type};

        my $pattern_class = $field_type eq 'dom' ? 'Cron::Describe::DayOfMonthPattern' :
                            $field_type eq 'dow' ? 'Cron::Describe::DayOfWeekPattern' :
                            'Cron::Describe::Pattern';
        eval "require $pattern_class";
        croak "Failed to load $pattern_class: $@" if $@;

        my $pattern = $pattern_class->new($value, @$range);
        if ($pattern->has_errors) {
            push @{$self->{errors}}, @{ $pattern->{errors} };
        }
        $self->{fields}{$field_type} = $pattern;
    }
}

sub validate {
    my ($self) = @_;
    return 0 if @{$self->{errors}};

    foreach my $field_type (keys %{$self->{fields}}) {
        my $pattern = $self->{fields}{$field_type};
        return 0 unless $pattern->validate();
    }

    if ($self->{type} eq 'quartz') {
        my $dom = $self->{fields}{dom};
        my $dow = $self->{fields}{dow};
        my $dom_pattern = $dom->{pattern_type};
        my $dow_pattern = $dow->{pattern_type};
        if ($dom_pattern ne 'unspecified' && $dow_pattern ne 'unspecified') {
            my $valid_dom_types = $dom_pattern eq 'wildcard' || $dom_pattern eq 'list' ||
                                  $dom_pattern =~ /^(last|last_weekday|nearest_weekday)$/;
            my $valid_dow_types = $dow_pattern eq 'wildcard' || $dow_pattern eq 'list' ||
                                  $dow_pattern =~ /^(nth|last_of_day)$/;
            if (!$valid_dom_types || !$valid_dow_types) {
                push @{$self->{errors}}, "Quartz: cannot specify both dom and dow unless wildcard or list";
                return 0;
            }
        }
        if ($dom_pattern eq 'unspecified' && $dow_pattern eq 'unspecified') {
            push @{$self->{errors}}, "Quartz: either dom or dow must be specified";
            return 0;
        }
    }

    return 1;
}

sub is_match {
    my ($self, $epoch) = @_;
    return 0 if @{$self->{errors}};

    my $date = Time::Moment->from_epoch($epoch);
    foreach my $field_type (keys %{$self->{fields}}) {
        my $value = $field_type eq 'seconds' ? $date->second :
                    $field_type eq 'minute' ? $date->minute :
                    $field_type eq 'hour' ? $date->hour :
                    $field_type eq 'dom' ? $date->day_of_month :
                    $field_type eq 'month' ? $date->month :
                    $field_type eq 'dow' ? $date->day_of_week % 7 :
                    $field_type eq 'year' ? $date->year : 0;
        return 0 unless $self->{fields}{$field_type}->is_match($value);
    }
    return 1;
}

sub to_english {
    my ($self) = @_;
    return "Invalid expression" if @{$self->{errors}};

    my @parts;
    my $is_quartz = $self->{type} eq 'quartz';
    my @time_fields = $is_quartz ? qw(seconds minute hour) : qw(minute hour);
    my @time_values = map { $self->{fields}{$_}{value} // 0 } @time_fields;

    my $time_part = @time_values && grep { $_ != 0 } @time_values
        ? join(":", map { sprintf("%02d", $_) } @time_values)
        : $is_quartz ? "00:00:00" : "00:00";
    push @parts, "at $time_part";

    foreach my $field_type (qw(dom month dow)) {
        my $desc = $self->{fields}{$field_type}->to_english();
        push @parts, $desc =~ /invalid/ ? "every $field_type" : ($field_type eq 'month' ? "in $desc" : $desc);
    }

    if ($self->{fields}{year}) {
        my $desc = $self->{fields}{year}->to_english();
        push @parts, $desc =~ /invalid/ ? "every year" : "in $desc";
    }

    return "Runs " . join(", ", grep { $_ } @parts);
}

sub to_string {
    my ($self) = @_;
    my @field_types = $self->{type} eq 'quartz'
        ? qw(seconds minute hour dom month dow year)
        : qw(minute hour dom month dow year);
    my @values;
    foreach my $field_type (@field_types) {
        last unless exists $self->{fields}{$field_type};
        push @values, $self->{fields}{$field_type}->to_string();
    }
    return join " ", @values;
}

1;
