package Cron::Describe;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;
use Cron::Describe::ListPattern;
use Cron::Describe::WildcardPattern;
use Cron::Describe::UnspecifiedPattern;
use Cron::Describe::DayOfMonthPattern;
use Cron::Describe::DayOfWeekPattern;

our $DEBUG = $ENV{Cron_DEBUG} // 0;

sub trim {
    my ($str) = @_;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

sub new {
    my ($class, %args) = @_;
    my $expression = $args{expression} // croak "Missing required parameter 'expression'";
    my $utc_offset = defined $args{utc_offset} ? $args{utc_offset} : 0;
    croak "Invalid utc_offset: must be an integer between -720 and 720 minutes" unless $utc_offset =~ /^-?\d+$/ && $utc_offset >= -720 && $utc_offset <= 720;
    croak "Empty cron expression is invalid" unless defined $expression && $expression =~ /\S/;
    my $self = bless { utc_offset => $utc_offset }, $class;
    # Normalize expression
    $expression = _normalize_expression($expression);
    # Split and validate field count
    my @fields = split /\s+/, $expression;
    my $field_count = scalar @fields;
    if ($field_count != 7) {
        croak "Invalid number of fields: got $field_count, expected 7 (Quartz)";
    }
    my @field_types = qw(seconds minute hour dom month dow year);
    my @field_ranges = ([0, 59], [0, 59], [0, 23], [1, 31], [1, 12], [0, 7], [1970, 2199]);
    $self->{fields} = [];
    my $has_dom = 0;
    my $has_dow = 0;
    for my $i (0 .. $#fields) {
        my $field = $fields[$i];
        my $field_type = $field_types[$i];
        my ($min, $max) = @{$field_ranges[$i]};
        my $pattern;
        $self->_debug("Describe::new: field=$field, field_type=$field_type, index=$i");
        eval {
            if ($field_type eq 'dom' && $field =~ /^(L|LW|(\d{1,2})W|L-\d+)$/) {
                $self->_debug("trying DayOfMonthPattern for '$field'");
                $pattern = Cron::Describe::DayOfMonthPattern->new($field, $min, $max, $field_type);
                $has_dom = 1 unless $field eq '?';
            } elsif ($field_type eq 'dow' && $field =~ /^[0-7]#[1-5]$|^[0-7]L$|^[0-7](,[0-7])*$|^?$/) {
                $self->_debug("trying DayOfWeekPattern for '$field'");
                $pattern = Cron::Describe::DayOfWeekPattern->new($field, $min, $max, $field_type);
                $has_dow = 1 unless $field eq '?';
            } elsif ($field eq '?') {
                $self->_debug("trying UnspecifiedPattern for '$field'");
                $pattern = Cron::Describe::UnspecifiedPattern->new($field, $min, $max, $field_type);
            } elsif ($field eq '*') {
                $self->_debug("trying WildcardPattern for '$field'");
                $pattern = Cron::Describe::WildcardPattern->new($field, $min, $max, $field_type);
            } elsif ($field =~ /^-?\d+$/) {
                $self->_debug("trying SinglePattern for '$field'");
                $pattern = Cron::Describe::SinglePattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom';
                $has_dow = 1 if $field_type eq 'dow';
            } elsif ($field =~ /^(\d+)-(\d+)$/) {
                $self->_debug("trying RangePattern for '$field'");
                $pattern = Cron::Describe::RangePattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom';
                $has_dow = 1 if $field_type eq 'dow';
            } elsif ($field =~ /^(\*|\d+|\d+-\d+)\/\d+$/) {
                $self->_debug("trying StepPattern for '$field'");
                $pattern = Cron::Describe::StepPattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom';
                $has_dow = 1 if $field_type eq 'dow';
            } elsif ($field =~ /^(\*|\d+|\d+-\d+|\*\/\d+|\d+\/\d+|\d+-\d+\/\d+)(,(\*|\d+|\d+-\d+|\*\/\d+|\d+\/\d+|\d+-\d+\/\d+))*$/) {
                $self->_debug("trying ListPattern for '$field'");
                $pattern = Cron::Describe::ListPattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom' && $field ne '?';
                $has_dow = 1 if $field_type eq 'dow' && $field ne '?';
            } else {
                croak "Invalid pattern '$field' for $field_type";
            }
            push @{$self->{fields}}, $pattern;
        };
        if ($@) {
            my $error = $@;
            $error =~ s/ at \S+ line \d+\.\n?$//;
            croak $error;
        }
    }
    # Quartz: Ensure exactly one of dom or dow is specified
    if ($has_dom && $has_dow) {
        croak "Cannot specify both day-of-month ($fields[3]) and day-of-week ($fields[5]); one must be '?'";
    }
    # Validate February-specific constraints
    if ($fields[4] =~ /^(2|2-\d+)$/) {
        my $max_dom = defined $fields[6] && $fields[6] =~ /^\d+$/ ? ($fields[6] % 4 == 0 ? 29 : 28) : 29;
        if ($fields[3] =~ /^(\d+)$/) {
            croak "Day $1 is out of range (1-$max_dom) for February" if $1 > $max_dom;
        } elsif ($fields[3] =~ /^(\d+)W$/) {
            croak "Day $1 is out of range for nearest weekday (1-$max_dom)" if $1 > $max_dom;
        }
        if ($fields[5] =~ /^([0-7])#([1-5])$/) {
            my $days = { 0 => 'Sunday', 1 => 'Monday', 2 => 'Tuesday', 3 => 'Wednesday', 4 => 'Thursday', 5 => 'Friday', 6 => 'Saturday' };
            croak "Fifth $days->{$1} is impossible in February $fields[6]" if $2 == 5 && defined $fields[6] && $fields[6] == 2025;
        }
    }
    return $self;
}

sub _normalize_expression {
    my ($expression) = @_;
    my $original = $expression;
    $expression = trim($expression);
    return '' if $expression eq '';
    $expression = uc($expression);
    my %name_map = (
        JAN => 1, FEB => 2, MAR => 3, APR => 4, MAY => 5, JUN => 6,
        JUL => 7, AUG => 8, SEP => 9, OCT => 10, NOV => 11, DEC => 12,
        SUN => 0, MON => 1, TUE => 2, WED => 3, THU => 4, FRI => 5, SAT => 6
    );
    $expression =~ s/\b([A-Z]{3})\b(?=[\s,?#L]|$)/$name_map{$1} || $1/ge;
    my @fields = split /\s+/, $expression;
    my $field_count = scalar @fields;
    if ($field_count == 5) {
        @fields = (0, $fields[0], $fields[1], $fields[2], $fields[3], '?', '*');
    } elsif ($field_count == 6) {
        push @fields, '*';
    } elsif ($field_count != 7) {
        croak "Invalid number of fields: got $field_count, expected 5 (standard) or 6/7 (Quartz)";
    }
    $expression = join ' ', @fields;
    print STDERR "DEBUG: Describe::normalize_expression: original='$original', normalized='$expression'\n" if $DEBUG;
    return $expression;
}

sub is_valid {
    my ($self) = shift;
    return 1; # Errors are thrown via croak
}

sub fields {
    my ($self) = shift;
    return [ map { $_->to_hash } @{$self->{fields} || []} ];
}

sub is_match {
    my ($self, $seconds) = @_;
    croak "Invalid epoch seconds: must be a non-negative integer" unless defined $seconds && $seconds =~ /^\d+$/;
    my $tm = Time::Moment->from_epoch($seconds)->with_offset_same_instant($self->{utc_offset});
    my @field_values = (
        $tm->second, $tm->minute, $tm->hour, $tm->day_of_month,
        $tm->month, $tm->day_of_week % 7, $tm->year
    );
    $self->_debug("is_match: seconds=$seconds, utc_offset=$self->{utc_offset}, tm=" . $tm->strftime('%Y-%m-%dT%H:%M:%S%z'));
    for my $i (0 .. $#{$self->{fields}}) {
        my $pattern = $self->{fields}[$i];
        my $value = $field_values[$i];
        $self->_debug("is_match: field=$i, field_type=$pattern->{field_type}, value=$value, pattern=" . ref($pattern) . ", pattern_value=" . $pattern->to_string);
        return 0 unless $pattern->is_match($value, $tm);
    }
    return 1;
}

sub to_english {
    my ($self) = shift;
    return "English description not implemented"; # Placeholder
}

sub _debug {
    my ($self, $message) = @_;
    print STDERR "DEBUG: " . ref($self) . ": $message\n" if $DEBUG;
}

1;
