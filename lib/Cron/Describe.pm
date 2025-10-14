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

# Define maps before regex construction
my %month_map = (
    'jan' => 1, 'january' => 1,
    'feb' => 2, 'february' => 2,
    'mar' => 3, 'march' => 3,
    'apr' => 4, 'april' => 4,
    'may' => 5,
    'jun' => 6, 'june' => 6,
    'jul' => 7, 'july' => 7,
    'aug' => 8, 'august' => 8,
    'sep' => 9, 'september' => 9,
    'oct' => 10, 'october' => 10,
    'nov' => 11, 'november' => 11,
    'dec' => 12, 'december' => 12
);

my %dow_map = (
    'sun' => 1, 'sunday' => 1,
    'mon' => 2, 'monday' => 2,
    'tue' => 3, 'tuesday' => 3,
    'wed' => 4, 'wednesday' => 4,
    'thu' => 5, 'thursday' => 5,
    'fri' => 6, 'friday' => 6,
    'sat' => 7, 'saturday' => 7
);

# Pre-compiled regex constants for optimization
use constant {
    SINGLE_RE => qr/^\d+$/,
    RANGE_RE => qr/^\d+-\d+$/,
    STEP_RE => qr/^(\*|\d+|\d+-\d+)\/\d+$/,
    LIST_RE => qr/^[^,]+(,[^,]+)+$/,  # Requires at least two comma-separated items
    DOM_SPECIAL_RE => qr/^(L(?:-\d+)?|LW|\d+W)$/,  # L, L-n, LW, nW
    DOW_SPECIAL_RE => qr/^\d+(L|#\d+)$/,  # nL, n#n
    MONTH_PATTERN_RE => qr/^(\d+|\d+-\d+|[\d,]+|\*|\d+-\d+\/\d+|\d+\/\d+)$/,  # Numeric only, post-normalization
    DOW_PATTERN_RE => qr/^(\d+L|\d+#\d+|[\d,]+|\*|\?|\d+-\d+)$/,  # Added \d+-\d+ for ranges
    MONTH_NAME_RE => do {
        my $month_re = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %month_map;
        qr/($month_re)/i;  # Capture group for $1
    },
    DOW_NAME_RE => do {
        my $dow_re = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %dow_map;
        qr/($dow_re)/i;  # Capture group for $1
    },
};

sub new {
    my ($class, $expression, %args) = @_;
    print STDERR "DEBUG: Describe::new: expression='$expression', args_utc_offset=$args{utc_offset}, object_utc_offset=" . ($args{utc_offset} // 0) . "\n" if $ENV{Cron_DEBUG};
    my $self = bless {
        expression => $expression,
        utc_offset => $args{utc_offset} // 0,
        patterns => [],
        is_valid => 1,
        error_message => '',
    }, $class;

    my $normalized;
    eval {
        $normalized = $self->normalize_expression($expression);
        print STDERR "DEBUG: Describe::normalize_expression: original='$expression'\n" if $ENV{Cron_DEBUG};
        print STDERR "DEBUG: Describe::normalize_expression: normalized='$normalized'\n" if $ENV{Cron_DEBUG};
    };
    if ($@) {
        print STDERR "DEBUG: Error in normalize_expression: $@\n" if $ENV{Cron_DEBUG};
        $self->{is_valid} = 0;
        $self->{error_message} = $@;
        return $self;
    }

    my @fields = split /\s+/, $normalized;
    croak "Invalid cron expression: expected 6 or 7 fields, got " . scalar(@fields) unless @fields >= 6 && @fields <= 7;

    my @field_types = qw(seconds minute hour dom month dow year);
    my @min_values = (0, 0, 0, 1, 1, 0, 1970);
    my @max_values = (59, 59, 23, 31, 12, 7, 2199);  # Aligned to Quartz docs

    if (@fields == 6) {
        push @fields, '*';
    }

    # Dispatch table for pattern creation
    my %pattern_dispatch = (
        qr/^\*$/ => sub { Cron::Describe::WildcardPattern->new($_[0], $min_values[$_[2]], $max_values[$_[2]], $_[1]) },
        qr/^\?$/ => sub { Cron::Describe::UnspecifiedPattern->new($_[0], $min_values[$_[2]], $max_values[$_[2]], $_[1]) },
        SINGLE_RE() => sub { Cron::Describe::SinglePattern->new($_[0], $min_values[$_[2]], $max_values[$_[2]], $_[1]) },
        RANGE_RE() => sub { Cron::Describe::RangePattern->new($_[0], $min_values[$_[2]], $max_values[$_[2]], $_[1]) },
        STEP_RE() => sub { Cron::Describe::StepPattern->new($_[0], $min_values[$_[2]], $max_values[$_[2]], $_[1]) },
        LIST_RE() => sub { Cron::Describe::ListPattern->new($_[0], $min_values[$_[2]], $max_values[$_[2]], $_[1]) },
    );

    for my $i (0..6) {
        my $field = $fields[$i];
        my $field_type = $field_types[$i];
        print STDERR "DEBUG: Describe::new: field='$field', field_type=$field_type, index=$i\n" if $ENV{Cron_DEBUG};
        my $pattern;

        eval {
            my $matched = 0;
            # Check dispatch table first for common patterns
            for my $re (keys %pattern_dispatch) {
                if ($field =~ $re) {
                    print STDERR "DEBUG: trying dispatch for '$field' with regex $re\n" if $ENV{Cron_DEBUG};
                    $pattern = $pattern_dispatch{$re}->($field, $field_type, $i);
                    $matched = 1;
                    last;
                }
            }

            # If not matched, check special patterns
            if (!$matched) {
                if ($field_type eq 'dom' && $field =~ DOM_SPECIAL_RE()) {
                    print STDERR "DEBUG: trying DayOfMonthPattern for '$field'\n" if $ENV{Cron_DEBUG};
                    $pattern = Cron::Describe::DayOfMonthPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
                    $matched = 1;
                } elsif ($field_type eq 'dow' && $field =~ DOW_SPECIAL_RE()) {
                    print STDERR "DEBUG: trying DayOfWeekPattern for '$field'\n" if $ENV{Cron_DEBUG};
                    $pattern = Cron::Describe::DayOfWeekPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
                    $matched = 1;
                }
            }

            print STDERR "DEBUG: field='$field', field_type=$field_type, matched=$matched\n" if $ENV{Cron_DEBUG};
            croak "Invalid pattern '$field' for $field_type" unless $matched;

            push @{$self->{patterns}}, $pattern;
        };
        if ($@) {
            print STDERR "DEBUG: Error in field parsing: $@\n" if $ENV{Cron_DEBUG};
            $self->{is_valid} = 0;
            $self->{error_message} = $@;
            return $self;
        }
    }

    # Simplified validation using extracted function
    $self->_validate_dom_month_combination();

    if ($self->{patterns}[3]->to_string ne '?' && $self->{patterns}[5]->to_string ne '?') {
        $self->{is_valid} = 0;
        $self->{error_message} = "Cannot specify both day-of-month and day-of-week; one must be '?'";
    }

    return $self;
}

# Getter/Setter for utc_offset
sub utc_offset {
    my ($self, $new_offset) = @_;
    if (@_ > 1) {  # Setter mode
        if (!defined $new_offset || $new_offset !~ /^-?\d+$/ || $new_offset < -1080 || $new_offset > 1080) {
            croak "Invalid utc_offset '$new_offset': must be an integer between -1080 and 1080 minutes";
        }
        $self->{utc_offset} = $new_offset;
        print STDERR "DEBUG: utc_offset: set to $new_offset\n" if $ENV{Cron_DEBUG};
    }
    print STDERR "DEBUG: utc_offset: returning $self->{utc_offset}\n" if $ENV{Cron_DEBUG};
    return $self->{utc_offset};
}

# Simplified validation function (optimization: reduce redundancy)
sub _validate_dom_month_combination {
    my ($self) = @_;
    my $dom = $self->{patterns}[3]->to_string;
    my $month = $self->{patterns}[4]->to_string;
    my $year = $self->{patterns}[6]->to_string;

    my $month_num = $month =~ SINGLE_RE() ? int($month) : undef;
    my $year_num = $year =~ SINGLE_RE() ? int($year) : undef;

    # Skip validation if month is not a single number (e.g., *)
    return unless defined $month_num;

    # Helper to validate a sub-pattern (e.g., day or range in list)
    my $validate_sub_pattern = sub {
        my ($sub_dom, $month_num, $error_prefix) = @_;
        if ($sub_dom =~ SINGLE_RE()) {
            my $day = int($sub_dom);
            if ($month_num == 2) {
                my $is_leap = defined $year_num ? Time::Moment->new(year => $year_num)->is_leap_year : 0;
                if ($day > 29 || ($day == 29 && !$is_leap)) {
                    $self->{is_valid} = 0;
                    $self->{error_message} = "$error_prefix $day is invalid for February (month $month_num)";
                    return 0;
                }
            } elsif ($day > 30 && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
                $self->{is_valid} = 0;
                $self->{error_message} = "$error_prefix $day is invalid for month $month_num";
                return 0;
            }
        } elsif ($sub_dom =~ RANGE_RE()) {
            my ($start, $end) = split /-/, $sub_dom;
            if ($month_num == 2) {
                my $is_leap = defined $year_num ? Time::Moment->new(year => $year_num)->is_leap_year : 0;
                if ($end > 29 || ($end == 29 && !$is_leap)) {
                    $self->{is_valid} = 0;
                    $self->{error_message} = "$error_prefix range $start-$end is invalid for February (month $month_num)";
                    return 0;
                }
            } elsif ($end > 30 && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
                $self->{is_valid} = 0;
                $self->{error_message} = "$error_prefix range $start-$end is invalid for month $month_num";
                return 0;
            }
        } elsif ($sub_dom =~ STEP_RE()) {
            my ($range, $step) = $sub_dom =~ STEP_RE();
            if ($month_num == 2) {
                my $is_leap = defined $year_num ? Time::Moment->new(year => $year_num)->is_leap_year : 0;
                if ($range eq '*' || ($range =~ RANGE_RE() && $2 > 29) || ($range =~ RANGE_RE() && $2 == 29 && !$is_leap)) {
                    $self->{is_valid} = 0;
                    $self->{error_message} = "$error_prefix step pattern $sub_dom is invalid for February (month $month_num)";
                    return 0;
                }
            } elsif (($range eq '*' || ($range =~ RANGE_RE() && $2 > 30)) && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
                $self->{is_valid} = 0;
                $self->{error_message} = "$error_prefix step pattern $sub_dom is invalid for month $month_num";
                return 0;
            }
        }
        return 1;
    };

    if ($dom =~ SINGLE_RE()) {
        $validate_sub_pattern->($dom, $month_num, "Day");
    } elsif ($dom =~ RANGE_RE()) {
        $validate_sub_pattern->($dom, $month_num, "Day");
    } elsif ($dom =~ STEP_RE()) {
        $validate_sub_pattern->($dom, $month_num, "Day");
    } elsif ($dom =~ LIST_RE()) {
        my @sub_doms = split /,/, $dom;
        foreach my $sub_dom (@sub_doms) {
            last unless $validate_sub_pattern->($sub_dom, $month_num, "Day");
        }
    }
}

sub normalize_expression {
    my ($self, $expression) = @_;
    croak "Empty cron expression is invalid" unless $expression;

    print STDERR "DEBUG: normalize_expression: before='$expression'\n" if $ENV{Cron_DEBUG};

    # Remove leading/trailing whitespace and normalize internal whitespace
    $expression =~ s/^\s+|\s+$//g;
    $expression =~ s/\s+/ /g;

    my @fields = split /\s+/, $expression;
    croak "Invalid cron expression: expected 6 or 7 fields, got " . scalar(@fields) unless @fields >= 6 && @fields <= 7;

    # If 6 fields, append '*' for year
    if (@fields == 6) {
        push @fields, '*';
    }

    # Process each field
    for my $i (0..$#fields) {
        my $field = $fields[$i];
        # Remove whitespace within fields (e.g., "1 , 2" -> "1,2")
        $field =~ s/\s+//g;

        # Handle day-of-month field (index 3)
        if ($i == 3) {
            # Validate no L in lists
            if ($field =~ /,/) {
                croak "Invalid use of 'L' in list for day-of-month" if $field =~ /\bL\b/;
                croak "Invalid use of 'W' in list for day-of-month" if $field =~ /W,/ || $field =~ /,W/;
            }
            # Validate no L or W in numeric ranges (exclude valid L-n)
            if ($field =~ /-/ && $field !~ DOM_SPECIAL_RE()) {
                croak "Invalid use of 'L' in range for day-of-month" if $field =~ /\bL\b/;
                croak "Invalid use of 'W' in range for day-of-month" if $field =~ /W-/ || $field =~ /-W/;
            }
            $field = uc($field);
        }

        # Handle month field (index 4)
        if ($i == 4) {
            # Normalize month names or ranges before validation
            if ($field =~ /^[a-zA-Z]+-[a-zA-Z]+$/) {
                my ($start, $end) = split /-/, $field;
                croak "Invalid month name '$start' in month field" unless $start =~ MONTH_NAME_RE();
                croak "Invalid month name '$end' in month field" unless $end =~ MONTH_NAME_RE();
                my $start_num = $month_map{lc($start)};
                my $end_num = $month_map{lc($end)};
                $field = "$start_num-$end_num";
            } elsif ($field =~ /[a-zA-Z]/) {
                my $original_field = $field;
                my @tokens = split /,/, $field;
                my @normalized_tokens;
                foreach my $token (@tokens) {
                    if ($token =~ /^[a-zA-Z]+$/) {
                        croak "Invalid month name '$token' in month field" unless $token =~ MONTH_NAME_RE();
                        push @normalized_tokens, $month_map{lc($token)};
                    } else {
                        push @normalized_tokens, $token;
                    }
                }
                $field = join ',', @normalized_tokens;
                print STDERR "DEBUG: normalize_expression: MONTH_NAME_RE substitution: '$original_field' -> '$field'\n" if $ENV{Cron_DEBUG};
            }
            # Validate pattern after substitution
            croak "Invalid pattern '$field' for month field" unless $field =~ MONTH_PATTERN_RE();
        }

        # Handle day-of-week field (index 5)
        if ($i == 5) {
            # Validate no W in dow field
            croak "Invalid use of 'W' in day-of-week field" if $field =~ /W/;
            # Normalize dow names or ranges before validation
            if ($field =~ /[a-zA-Z]/) {
                my $original_field = $field;
                if ($field =~ /^[a-zA-Z]+-[a-zA-Z]+$/) {  # Handle ranges like MON-FRI
                    my ($start, $end) = split /-/, $field;
                    croak "Invalid day name '$start' in day-of-week field" unless $start =~ DOW_NAME_RE();
                    croak "Invalid day name '$end' in day-of-week field" unless $end =~ DOW_NAME_RE();
                    my $start_num = $dow_map{lc($start)};
                    my $end_num = $dow_map{lc($end)};
                    $field = "$start_num-$end_num";
                    print STDERR "DEBUG: normalize_expression: DOW_NAME_RE range substitution: '$original_field' -> '$field'\n" if $ENV{Cron_DEBUG};
                } else {
                    my @tokens = split /,/, $field;
                    my @normalized_tokens;
                    foreach my $token (@tokens) {
                        if ($token =~ /^[a-zA-Z]+$/) {
                            croak "Invalid day name '$token' in day-of-week field" unless $token =~ DOW_NAME_RE();
                            push @normalized_tokens, $dow_map{lc($token)};
                        } else {
                            push @normalized_tokens, $token;
                        }
                    }
                    $field = join ',', @normalized_tokens;
                    print STDERR "DEBUG: normalize_expression: DOW_NAME_RE substitution: '$original_field' -> '$field'\n" if $ENV{Cron_DEBUG};
                }
            }
            # Validate normalized field
            croak "Invalid pattern '$field' for dow" unless $field =~ DOW_PATTERN_RE();
            $field = uc($field);
        }

        $fields[$i] = $field;
    }

    # Rejoin fields with single spaces
    my $normalized = join ' ', @fields;
    print STDERR "DEBUG: normalize_expression: after='$normalized'\n" if $ENV{Cron_DEBUG};
    return $normalized;
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

    print STDERR "DEBUG: is_match: Time::Moment_version=$Time::Moment::VERSION\n" if $ENV{Cron_DEBUG};
    print STDERR "DEBUG: is_match: input_epoch=" . $tm->epoch . ", utc_time=" . $tm->strftime('%Y-%m-%d %H:%M:%S %z') . ", input_offset=" . $tm->offset . "\n" if $ENV{Cron_DEBUG};
    my $tm_adjusted = $tm->with_offset_same_instant($self->{utc_offset});
    print STDERR "DEBUG: is_match: adjusted_time=" . $tm_adjusted->strftime('%Y-%m-%d %H:%M:%S %z') . ", adjusted_offset=" . $tm_adjusted->offset . ", utc_offset=$self->{utc_offset}\n" if $ENV{Cron_DEBUG};
    my @values = (
        $tm_adjusted->second,
        $tm_adjusted->minute,
        $tm_adjusted->hour,
        $tm_adjusted->day_of_month,
        $tm_adjusted->month,
        quartz_dow($tm_adjusted->day_of_week),
        $tm_adjusted->year
    );
    my @pattern_values = map { $_->to_string } @{$self->{patterns}};
    print STDERR "DEBUG: is_match: components=[second=$values[0], minute=$values[1], hour=$values[2], dom=$values[3], month=$values[4], dow=$values[5], year=$values[6]], expected=[second=$pattern_values[0], minute=$pattern_values[1], hour=$pattern_values[2], dom=$pattern_values[3], month=$pattern_values[4], dow=$pattern_values[5], year=$pattern_values[6]]\n" if $ENV{Cron_DEBUG};

    for my $i (0..6) {
        my $field_type = [qw(seconds minute hour dom month dow year)]->[$i];
        my $pattern_value = $self->{patterns}[$i] ? $self->{patterns}[$i]->to_string : 'undef';
        print STDERR "DEBUG: is_match: field=$i, field_type=$field_type, value=$values[$i], pattern=" . (ref($self->{patterns}[$i]) || 'undef') . ", pattern_value=$pattern_value, utc_offset=$self->{utc_offset}\n" if $ENV{Cron_DEBUG};
        my $match = $self->{patterns}[$i] && $self->{patterns}[$i]->is_match($values[$i], $tm_adjusted);
        print STDERR "DEBUG: is_match: Match " . ($match ? "succeeded" : "failed") . " for field=$i ($field_type, value=$values[$i], pattern_value=$pattern_value)\n" if $ENV{Cron_DEBUG};
        return 0 unless $match;
    }
    print STDERR "DEBUG: is_match: All fields matched, returning 1\n" if $ENV{Cron_DEBUG};
    return 1;
}

1;
