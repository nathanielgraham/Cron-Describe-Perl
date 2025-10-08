package Cron::Describe::CronExpression;
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

sub new {
    my ($class, $expression) = @_;
    croak "Empty cron expression is invalid" unless defined $expression && $expression =~ /\S/;

    my $self = bless {}, $class;

    # Split and validate field count
    my @fields = split /\s+/, $expression;
    my $field_count = scalar @fields;

    # Standard cron: 5 fields, Quartz: 6 or 7 fields
    if ($field_count == 6 || $field_count == 7) {
        $self = bless $self, 'Cron::Describe::Quartz';
        $self->{is_quartz} = 1;
    } elsif ($field_count == 5) {
        $self->{is_quartz} = 0;
    } else {
        croak "Invalid number of fields: got $field_count, expected 5 (standard) or 6/7 (Quartz)";
    }

    my @field_types = $self->{is_quartz}
        ? qw(seconds minute hour dom month dow year)
        : qw(minute hour dom month dow);
    my @field_ranges = $self->{is_quartz}
        ? ([0, 59], [0, 59], [0, 23], [1, 31], [1, 12], [0, 7], [1970, 2199])
        : ([0, 59], [0, 23], [1, 31], [1, 12], [0, 7]);

    $self->{fields} = [];
    my $has_dom = 0;
    my $has_dow = 0;

    for my $i (0 .. $#fields) {
        my $field = $fields[$i];
        my $field_type = $field_types[$i];
        my ($min, $max) = @{$field_ranges[$i]};

        my $pattern;
        print STDERR "DEBUG: CronExpression::new: field=$field, field_type=$field_type, index=$i\n";
        eval {
            if ($field_type eq 'dom' && $self->{is_quartz} && $field =~ /^(L|LW|(\d{1,2})W|L-\d+)$/) {
                print STDERR "DEBUG: CronExpression::new: trying DayOfMonthPattern for '$field'\n";
                $pattern = Cron::Describe::DayOfMonthPattern->new($field, $min, $max, $field_type);
                $has_dom = 1 unless $field eq '?';
            } elsif ($field_type eq 'dow' && $self->{is_quartz} && $field =~ /^[0-7]#[1-5]$|^[0-7]L$|^(MON|TUE|WED|THU|FRI|SAT|SUN)(,(MON|TUE|WED|THU|FRI|SAT|SUN))*$|^?$/) {
                print STDERR "DEBUG: CronExpression::new: trying DayOfWeekPattern for '$field'\n";
                $pattern = Cron::Describe::DayOfWeekPattern->new($field, $min, $max, $field_type);
                $has_dow = 1 unless $field eq '?';
            } elsif ($field eq '?' && $self->{is_quartz} && ($field_type eq 'dom' || $field_type eq 'dow')) {
                print STDERR "DEBUG: CronExpression::new: trying UnspecifiedPattern for '$field'\n";
                $pattern = Cron::Describe::UnspecifiedPattern->new($field, $min, $max, $field_type);
            } elsif ($field eq '*') {
                print STDERR "DEBUG: CronExpression::new: trying WildcardPattern for '$field'\n";
                $pattern = Cron::Describe::WildcardPattern->new($field, $min, $max, $field_type);
            } elsif ($field =~ /^-?\d+$/) { # Handle numeric inputs (including negative) first
                print STDERR "DEBUG: CronExpression::new: trying SinglePattern for '$field'\n";
                $pattern = Cron::Describe::SinglePattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom';
                $has_dow = 1 if $field_type eq 'dow';
            } elsif ($field =~ /^(\d+)-(\d+)$/) {
                print STDERR "DEBUG: CronExpression::new: trying RangePattern for '$field'\n";
                $pattern = Cron::Describe::RangePattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom';
                $has_dow = 1 if $field_type eq 'dow';
            } elsif ($field =~ /^(\*|\d+|\d+-\d+)\/\d+$/) {
                print STDERR "DEBUG: CronExpression::new: trying StepPattern for '$field'\n";
                $pattern = Cron::Describe::StepPattern->new($field, $min, $max, $field_type);
                $has_dom = 1 if $field_type eq 'dom';
                $has_dow = 1 if $field_type eq 'dow';
            } elsif ($field =~ /^(\*|\d+|\d+-\d+|\*\/\d+|\d+\/\d+|\d+-\d+\/\d+)(,(\*|\d+|\d+-\d+|\*\/\d+|\d+\/\d+|\d+-\d+\/\d+))*$/) {
                print STDERR "DEBUG: CronExpression::new: trying ListPattern for '$field'\n";
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

    # Quartz: Ensure exactly one of dom or dow is specified (not both, unless one is ?)
    if ($self->{is_quartz} && $has_dom && $has_dow) {
        croak "Cannot specify both day-of-month ($fields[3]) and day-of-week ($fields[5]) in Quartz";
    }

    # Validate February-specific constraints
    if ($self->{is_quartz} && $fields[4] =~ /^(2|2-\d+)$/) {
        my $max_dom = defined $fields[6] ? ($fields[6] % 4 == 0 ? 29 : 28) : 29;
        if ($fields[3] =~ /^(\d+)$/) {
            croak "Day $1 is out of range (1-$max_dom) for February" if $1 > $max_dom;
        } elsif ($fields[3] =~ /^(\d+)W$/) {
            croak "Day $1 is out of range for nearest weekday (1-$max_dom)" if $1 > $max_dom;
        }
    }
    if ($self->{is_quartz} && $fields[5] =~ /^([0-7])#([1-5])$/) {
        my $year = defined $fields[6] ? $fields[6] : 0;
        my $max_days = ($year && $year % 4 == 0) ? 29 : 28;
        my $day_name = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')[$1];
        $day_name = 'Sunday' if $1 == 0 || $1 == 7;
        my $nth = $2;
        my $max_nth = $fields[4] eq '2' ? ($max_days == 29 ? 5 : 4) : 5;
        my @nth_words = ('', 'First', 'Second', 'Third', 'Fourth', 'Fifth', 'Sixth');
        croak "$nth_words[$nth] $day_name is impossible in " . ($fields[4] eq '2' ? "February $year" : "any month") if $nth > $max_nth;
    }

    return $self;
}

sub is_valid {
    my $self = shift;
    return 1; # Errors are thrown via croak
}

sub fields {
    my $self = shift;
    return [ map { $_->to_hash } @{$self->{fields} || []} ];
}

sub is_match {
    my ($self, $tm) = @_;
    my @field_values = $self->{is_quartz}
        ? ($tm->second, $tm->minute, $tm->hour, $tm->day_of_month, $tm->month, $tm->day_of_week % 7, $tm->year)
        : ($tm->minute, $tm->hour, $tm->day_of_month, $tm->month, $tm->day_of_week % 7);

    for my $i (0 .. $#{$self->{fields}}) {
        print STDERR "DEBUG: is_match: field=$i, value=$field_values[$i], pattern=" . ref($self->{fields}[$i]) . "\n";
        return 0 unless $self->{fields}[$i]->is_match($field_values[$i], $tm);
    }
    return 1;
}

sub to_english {
    my $self = shift;
    return "English description not implemented"; # Placeholder for future implementation
}

package Cron::Describe::Quartz;
use parent 'Cron::Describe::CronExpression';

1;
