package Cron::Describe;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;
use Cron::Describe::WildcardPattern;
use Cron::Describe::UnspecifiedPattern;
use Cron::Describe::DayOfMonthPattern;
use Cron::Describe::DayOfWeekPattern;
use Cron::Describe::ListPattern;

sub new {
    my ($class, $expression, %args) = @_;
    print STDERR "DEBUG: Describe::new: expression='$expression', utc_offset=$args{utc_offset}\n" if $ENV{Cron_DEBUG};
    my $self = bless {
        expression => $expression,
        utc_offset => $args{utc_offset} // 0,
        patterns => [],
        is_valid => 1,
        error_message => '',
    }, $class;

    my $normalized = $self->normalize_expression($expression);
    print STDERR "DEBUG: Describe::normalize_expression: original='$expression'\n" if $ENV{Cron_DEBUG};
    print STDERR "DEBUG: Describe::normalize_expression: normalized='$normalized'\n" if $ENV{Cron_DEBUG};

    my @fields = split /\s+/, $normalized;
    croak "Invalid cron expression: expected 6 or 7 fields, got " . scalar(@fields) unless @fields >= 6 && @fields <= 7;

    my @field_types = qw(seconds minute hour dom month dow year);
    my @min_values = (0, 0, 0, 1, 1, 0, 1970);
    my @max_values = (59, 59, 23, 31, 12, 7, 2199);

    if (@fields == 6) {
        push @fields, '*';
    }

    for my $i (0..6) {
        my $field = $fields[$i];
        my $field_type = $field_types[$i];
        print STDERR "DEBUG: Describe::new: field='$field', field_type=$field_type, index=$i\n" if $ENV{Cron_DEBUG};
        my $pattern;

        eval {
            if ($field =~ /^\d+$/) {
                print STDERR "DEBUG: trying SinglePattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::SinglePattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field =~ /^\d+-\d+$/) {
                print STDERR "DEBUG: trying RangePattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::RangePattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field =~ /^(\*|\d+|\d+-\d+)\/\d+$/) {
                print STDERR "DEBUG: trying StepPattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::StepPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field eq '*') {
                print STDERR "DEBUG: trying WildcardPattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::WildcardPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field eq '?') {
                print STDERR "DEBUG: trying UnspecifiedPattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::UnspecifiedPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field_type eq 'dom' && $field =~ /^[LW\d-]+$/) {
                print STDERR "DEBUG: trying DayOfMonthPattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::DayOfMonthPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field_type eq 'dow' && $field =~ /^(\d+(L|#\d+))$/) {
                print STDERR "DEBUG: trying DayOfWeekPattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::DayOfWeekPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } elsif ($field =~ /^[^,]+(,[^,]+)*$/) {
                print STDERR "DEBUG: trying ListPattern for '$field'\n" if $ENV{Cron_DEBUG};
                $pattern = Cron::Describe::ListPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
            } else {
                croak "Invalid pattern '$field' for $field_type";
            }
            push @{$self->{patterns}}, $pattern;
        };
        if ($@) {
            print STDERR "DEBUG: Error: $@\n" if $ENV{Cron_DEBUG};
            $self->{is_valid} = 0;
            $self->{error_message} = $@;
            return $self;
        }
    }

    # Validate day-of-month and month combinations
    my $dom = $self->{patterns}[3]->to_string;
    my $month = $self->{patterns}[4]->to_string;
    if ($dom =~ /^\d+$/ && $month =~ /^\d+$/) {
        my $day = int($dom);
        my $month_num = int($month);
        if ($month_num == 2 && $day > 29) {
            $self->{is_valid} = 0;
            $self->{error_message} = "Day $day is invalid for February (month $month_num)";
            return $self;
        } elsif ($day > 30 && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
            $self->{is_valid} = 0;
            $self->{error_message} = "Day $day is invalid for month $month_num";
            return $self;
        }
    } elsif ($dom =~ /^(\d+)-(\d+)$/) {
        my ($start, $end) = ($1, $2);
        my $month_num = $month =~ /^\d+$/ ? int($month) : undef;
        if ($month_num && $month_num == 2 && $end > 29) {
            $self->{is_valid} = 0;
            $self->{error_message} = "Day range $start-$end is invalid for February (month $month_num)";
            return $self;
        } elsif ($month_num && $end > 30 && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
            $self->{is_valid} = 0;
            $self->{error_message} = "Day range $start-$end is invalid for month $month_num";
            return $self;
        }
    } elsif ($dom =~ /^(\*|\d+|\d+-\d+)\/(\d+)$/) {
        my ($range, $step) = ($1, $2);
        my $month_num = $month =~ /^\d+$/ ? int($month) : undef;
        if ($month_num && $month_num == 2 && ($range eq '*' || ($range =~ /^(\d+)-(\d+)$/ && $2 > 29))) {
            $self->{is_valid} = 0;
            $self->{error_message} = "Step pattern $dom is invalid for February (month $month_num)";
            return $self;
        } elsif ($month_num && ($range eq '*' || ($range =~ /^(\d+)-(\d+)$/ && $2 > 30)) && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
            $self->{is_valid} = 0;
            $self->{error_message} = "Step pattern $dom is invalid for month $month_num";
            return $self;
        }
    } elsif ($dom =~ /^[^,]+(,[^,]+)*$/) {
        my @days = split /,/, $dom;
        my $month_num = $month =~ /^\d+$/ ? int($month) : undef;
        if ($month_num && $month_num == 2) {
            foreach my $day (@days) {
                if ($day =~ /^\d+$/ && $day > 29) {
                    $self->{is_valid} = 0;
                    $self->{error_message} = "Day $day in list $dom is invalid for February (month $month_num)";
                    return $self;
                } elsif ($day =~ /^(\d+)-(\d+)$/) {
                    my ($start, $end) = ($1, $2);
                    if ($end > 29) {
                        $self->{is_valid} = 0;
                        $self->{error_message} = "Day range $start-$end in list $dom is invalid for February (month $month_num)";
                        return $self;
                    }
                } elsif ($day =~ /^(\*|\d+|\d+-\d+)\/(\d+)$/) {
                    my ($range, $step) = ($1, $2);
                    if ($range eq '*' || ($range =~ /^(\d+)-(\d+)$/ && $2 > 29)) {
                        $self->{is_valid} = 0;
                        $self->{error_message} = "Step pattern $day in list $dom is invalid for February (month $month_num)";
                        return $self;
                    }
                }
            }
        } elsif ($month_num && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
            foreach my $day (@days) {
                if ($day =~ /^\d+$/ && $day > 30) {
                    $self->{is_valid} = 0;
                    $self->{error_message} = "Day $day in list $dom is invalid for month $month_num";
                    return $self;
                } elsif ($day =~ /^(\d+)-(\d+)$/) {
                    my ($start, $end) = ($1, $2);
                    if ($end > 30) {
                        $self->{is_valid} = 0;
                        $self->{error_message} = "Day range $start-$end in list $dom is invalid for month $month_num";
                        return $self;
                    }
                } elsif ($day =~ /^(\*|\d+|\d+-\d+)\/(\d+)$/) {
                    my ($range, $step) = ($1, $2);
                    if ($range eq '*' || ($range =~ /^(\d+)-(\d+)$/ && $2 > 30)) {
                        $self->{is_valid} = 0;
                        $self->{error_message} = "Step pattern $day in list $dom is invalid for month $month_num";
                        return $self;
                    }
                }
            }
        }
    }

    if ($self->{patterns}[3]->to_string ne '?' && $self->{patterns}[5]->to_string ne '?') {
        $self->{is_valid} = 0;
        $self->{error_message} = "Cannot specify both day-of-month and day-of-week; one must be '?'";
    }

    return $self;
}

sub normalize_expression {
    my ($self, $expression) = @_;
    $expression =~ s/^\s+|\s+$//g;
    croak "Empty cron expression is invalid" unless $expression;
    my @fields = split /\s+/, $expression;
    croak "5-field cron expressions not supported; use 6 or 7-field Quartz format" if @fields == 5;
    croak "Invalid cron expression: expected 6 or 7 fields, got " . scalar(@fields) unless @fields >= 6 && @fields <= 7;
    if (@fields == 6) {
        push @fields, '*';
    }
    return join ' ', @fields;
}

sub is_valid {
    my ($self) = @_;
    return $self->{is_valid};
}

sub error_message {
    my ($self) = @_;
    return $self->{error_message};
}

sub to_hash {
    my ($self) = @_;
    return [ map { $_->to_hash } @{$self->{patterns}} ];
}

sub to_string {
    my ($self) = @_;
    return join ' ', map { $_->to_string } @{$self->{patterns}};
}

sub quartz_dow {
    my ($iso_dow) = @_;
    return $iso_dow == 7 ? 1 : $iso_dow + 1;
}

sub is_match {
    my ($self, $tm) = @_;
    croak "Time::Moment object required" unless ref($tm) eq 'Time::Moment';

    my $tm_adjusted = $tm->with_offset_same_instant($self->{utc_offset});
    my @values = (
        $tm_adjusted->second,
        $tm_adjusted->minute,
        $tm_adjusted->hour,
        $tm_adjusted->day_of_month,
        $tm_adjusted->month,
        quartz_dow($tm_adjusted->day_of_week),
        $tm_adjusted->year
    );

    for my $i (0..6) {
        my $field_type = [qw(seconds minute hour dom month dow year)]->[$i];
        print STDERR "DEBUG: is_match: field=$i, field_type=$field_type, value=$values[$i], pattern=" . (ref($self->{patterns}[$i]) || 'undef') . ", pattern_value=" . ($self->{patterns}[$i] ? $self->{patterns}[$i]->to_string : 'undef') . "\n" if $ENV{Cron_DEBUG};
        return 0 unless $self->{patterns}[$i] && $self->{patterns}[$i]->is_match($values[$i], $tm_adjusted);
    }
    return 1;
}

1;
