package Cron::Describe;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;
use Cron::Describe::Utils qw( :all );
use Cron::Describe::SinglePattern;
use Cron::Describe::RangePattern;
use Cron::Describe::StepPattern;
use Cron::Describe::WildcardPattern;
use Cron::Describe::UnspecifiedPattern;
use Cron::Describe::DayOfMonthPattern;
use Cron::Describe::DayOfWeekPattern;
use Cron::Describe::ListPattern;

use constant {
    SINGLE_RE         => qr/^\d+$/,
    RANGE_RE          => qr/^\d+-\d+$/,
    STEP_RE           => qr/^(\*|\d+|\d+-\d+)\/\d+$/,
    LIST_RE           => qr/^[^,]+(,[^,]+)+$/,
    DOM_SPECIAL_RE    => qr/^(L(?:-\d+)?|LW|\d+W)$/,
    DOW_SPECIAL_RE    => qr/^\d+(L|#\d+)$/,
    MONTH_PATTERN_RE  => qr/^(\d+|\d+-\d+|[\d,]+|\*|\d+-\d+\/\d+|\d+\/\d+)$/,
    DOW_PATTERN_RE    => qr/^(\d+L|\d+#\d+|[\d,]+|\*|\?|\d+-\d+|(\d+-\d+|\d+|\*)\/\d+)$/,
    MONTH_NAME_RE     => do {
        my $month_re = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %month_map;
        qr/($month_re)/i;
    },
    DOW_NAME_RE       => do {
        my $dow_re = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %dow_map;
        qr/($dow_re)/i;
    },
};

# Pre-compiled regex constants (Describe.pm only)
#use constant {
#    SINGLE_RE         => qr/^\d+$/,
#    RANGE_RE          => qr/^\d+-\d+$/,
#    STEP_RE           => qr/^(\*|\d+|\d+-\d+)\/\d+$/,
#    LIST_RE           => qr/^[^,]+(,[^,]+)+$/,
#    DOM_SPECIAL_RE    => qr/^(L(?:-\d+)?|LW|\d+W)$/,
#    DOW_SPECIAL_RE    => qr/^\d+(L|#\d+)$/,
#    MONTH_PATTERN_RE  => qr/^(\d+|\d+-\d+|[\d,]+|\*|\d+-\d+\/\d+|\d+\/\d+)$/,
    #DOW_PATTERN_RE    => qr/^(\d+L|\d+#\d+|[\d,]+|\*|\?|\d+-\d+)$/,
#    DOW_PATTERN_RE    => qr/^(\d+L|\d+#\d+|[\d,]+|\*|\?|\d+-\d+|(\d+-\d+|\d+|\*)\/\d+)$/,
#    MONTH_NAME_RE     => do {
#        my $month_re = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %month_map;
#        qr/($month_re)/i;
#    },
#    DOW_NAME_RE       => do {
#        my $dow_re = join '|', map { quotemeta } sort { length($b) <=> length($a) } keys %dow_map;
#        qr/($dow_re)/i;
#    },
#};

sub new_from_quartz {
    my ($class, %args) = @_;
    my $expression = delete $args{expression} // croak "Missing 'expression'";
    my $utc = delete $args{utc} // delete $args{utc_offset} // 0;
    croak "Unknown params: " . join(", ", keys %args) if keys %args;
    
    print STDERR "DEBUG: Describe::new_from_quartz: expression='$expression', utc_offset=$utc\n" if $ENV{Cron_DEBUG};
    my $self = bless {
        expression => $expression,
        utc_offset => $utc,
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
    croak "Quartz cron must have 6 or 7 fields, got " . scalar(@fields) unless @fields >= 6 && @fields <= 7;

    my @field_types = qw(seconds minute hour dom month dow year);
    my @min_values = (0, 0, 0, 1, 1, 0, 1970);
    my @max_values = (59, 59, 23, 31, 12, 7, 2199);

    if (@fields == 6) {
        push @fields, '*';
    }

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
        print STDERR "DEBUG: Describe::new_from_quartz: field='$field', field_type=$field_type, index=$i\n" if $ENV{Cron_DEBUG};
        my $pattern;

        eval {
            my $matched = 0;
            for my $re (keys %pattern_dispatch) {
                if ($field =~ $re) {
                    print STDERR "DEBUG: trying dispatch for '$field' with regex $re\n" if $ENV{Cron_DEBUG};
                    $pattern = $pattern_dispatch{$re}->($field, $field_type, $i);
                    $matched = 1;
                    last;
                }
            }

            if (!$matched) {
                if ($field_type eq 'dom' && $field =~ DOM_SPECIAL_RE) {
                    print STDERR "DEBUG: trying DayOfMonthPattern for '$field'\n" if $ENV{Cron_DEBUG};
                    $pattern = Cron::Describe::DayOfMonthPattern->new($field, $min_values[$i], $max_values[$i], $field_type);
                    $matched = 1;
                } elsif ($field_type eq 'dow' && $field =~ DOW_SPECIAL_RE) {
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

    $self->_validate_dom_month_combination();

    if ($self->{patterns}[3]->to_string ne '?' && $self->{patterns}[5]->to_string ne '?') {
        $self->{is_valid} = 0;
        $self->{error_message} = "Cannot specify both day-of-month and day-of-week; one must be '?'";
    }

    return $self;
}

sub new_from_unix {
    my ($class, %args) = @_;
    my $expression = delete $args{expression} // croak "Missing 'expression'";
    my $tz = delete $args{tz} // delete $args{time_zone};
    my $utc = delete $args{utc} // delete $args{utc_offset} // 0;
    $utc = $class->_tz_to_utc_offset($tz) if $tz && $utc == 0;
    croak "Unknown params: " . join(", ", keys %args) if keys %args;
    
    my $quartz_expr = $class->_unix_to_quartz($expression);
    return $class->new_from_quartz(
        expression => $quartz_expr, 
        utc => $utc
    );
}

sub new {
    my ($class, %args) = @_;
    my $expression = delete $args{expression} // croak "Missing 'expression'";
    my $tz = delete $args{tz} // delete $args{time_zone};
    my $utc = delete $args{utc} // delete $args{utc_offset} // 0;
    $utc = $class->_tz_to_utc_offset($tz) if $tz && $utc == 0;
    croak "Unknown params: " . join(", ", keys %args) if keys %args;
    
    my @fields = split /\s+/, $expression;
    if (@fields == 5) {
        return $class->new_from_unix(
            expression => $expression, 
            utc => $utc
        );
    } else {
        return $class->new_from_quartz(
            expression => $expression, 
            utc => $utc
        );
    }
}

sub _unix_to_quartz {
    my ($class, $expression) = @_;
    my @fields = split /\s+/, $expression;
    croak "Unix cron must have exactly 5 fields, got " . scalar(@fields) unless @fields == 5;

    my ($min, $hour, $dom, $month, $dow) = @fields;

    # Unix NO special chars (? L W #)
    for my $field ($min, $hour, $dom, $month, $dow) {
        croak "Unix cron cannot contain special characters: '$field'" if $field =~ /[?LW#]/;
    }

    # Unix DOW: 0/7=Sun→1, 1=Mon→2, ..., 6=Sat→7
    $dow =~ s/\b0\b|7/1/g;
    $dow =~ s/\b(\d)\b/$1+1/eeg;

    # Check DOM/DOW conflict (both non-*)
    my $dom_star = $dom eq '*';
    my $dow_star = $dow eq '*';
    croak "Unix cron cannot specify both day-of-month and day-of-week (DOM='$dom', DOW='$dow')"
        unless $dom_star || $dow_star;

    # FIXED LOGIC: PREFER DOM (keep specified, ? other)
    my $quartz_dom = $dom_star ? '*' : $dom;
    my $quartz_dow = $dow_star ? '*' : $dow;

    # Every day: DOM=* DOW=* → DOW=?
    if ($dom_star && $dow_star) {
        $quartz_dow = '?';
    }
    # DOM specified → DOW=?
    elsif (!$dom_star) {
        $quartz_dow = '?';
    }
    # DOW specified → DOM=?
    else {
        $quartz_dom = '?';
    }

    # FULL PADDING: SEC=0, MIN, HOUR, DOM, MONTH, DOW, YEAR=*
    return join ' ', 0, $min, $hour, $quartz_dom, $month, $quartz_dow, '*';
}

sub _tz_to_utc_offset {
    my ($class, $tz) = @_;
    return 0 unless $tz;
    eval {
        require DateTime::TimeZone;
        my $zone = DateTime::TimeZone->new(name => $tz) || croak "Invalid timezone '$tz'";
        my $tm = Time::Moment->now();
        my $offset = $zone->offset_for_datetime($tm) / 60;
        return $offset;
    };
    croak "Invalid timezone '$tz': $@" if $@;
}

sub utc_offset {
    my ($self, $new_offset) = @_;
    if (@_ > 1) {
        if (!defined $new_offset || $new_offset !~ /^-?\d+$/ || $new_offset < -1080 || $new_offset > 1080) {
            croak "Invalid utc_offset '$new_offset': must be an integer between -1080 and 1080 minutes";
        }
        $self->{utc_offset} = $new_offset;
        print STDERR "DEBUG: utc_offset: set to $new_offset\n" if $ENV{Cron_DEBUG};
    }
    print STDERR "DEBUG: utc_offset: returning $self->{utc_offset}\n" if $ENV{Cron_DEBUG};
    return $self->{utc_offset};
}

sub _validate_dom_month_combination {
    my ($self) = @_;
    my $dom = $self->{patterns}[3]->to_string;
    my $month = $self->{patterns}[4]->to_string;
    my $year = $self->{patterns}[6]->to_string;

    my $month_num = $month =~ SINGLE_RE ? int($month) : undef;
    my $year_num = $year =~ SINGLE_RE ? int($year) : undef;

    return unless defined $month_num;

    my $validate_sub_pattern = sub {
        my ($sub_dom, $month_num, $error_prefix) = @_;
        if ($sub_dom =~ SINGLE_RE) {
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
        } elsif ($sub_dom =~ RANGE_RE) {
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
        } elsif ($sub_dom =~ STEP_RE) {
            my ($range, $step) = $sub_dom =~ STEP_RE;
            if ($month_num == 2) {
                my $is_leap = defined $year_num ? Time::Moment->new(year => $year_num)->is_leap_year : 0;
                if ($range eq '*' || ($range =~ RANGE_RE && $2 > 29) || ($range =~ RANGE_RE && $2 == 29 && !$is_leap)) {
                    $self->{is_valid} = 0;
                    $self->{error_message} = "$error_prefix step pattern $sub_dom is invalid for February (month $month_num)";
                    return 0;
                }
            } elsif (($range eq '*' || ($range =~ RANGE_RE && $2 > 30)) && ($month_num == 4 || $month_num == 6 || $month_num == 9 || $month_num == 11)) {
                $self->{is_valid} = 0;
                $self->{error_message} = "$error_prefix step pattern $sub_dom is invalid for month $month_num";
                return 0;
            }
        }
        return 1;
    };

    if ($dom =~ SINGLE_RE) {
        $validate_sub_pattern->($dom, $month_num, "Day");
    } elsif ($dom =~ RANGE_RE) {
        $validate_sub_pattern->($dom, $month_num, "Day");
    } elsif ($dom =~ STEP_RE) {
        $validate_sub_pattern->($dom, $month_num, "Day");
    } elsif ($dom =~ LIST_RE) {
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

    $expression =~ s/^\s+|\s+$//g;
    $expression =~ s/\s+/ /g;

    my @fields = split /\s+/, $expression;
    croak "Invalid cron expression: expected 6 or 7 fields, got " . scalar(@fields) unless @fields >= 6 && @fields <= 7;

    if (@fields == 6) {
        push @fields, '*';
    }

    for my $i (0..$#fields) {
        my $field = $fields[$i];
        $field =~ s/\s+//g;

        if ($i == 3) {
            if ($field =~ /,/) {
                croak "Invalid use of 'L' in list for day-of-month" if $field =~ /\bL\b/;
                croak "Invalid use of 'W' in list for day-of-month" if $field =~ /W,/ || $field =~ /,W/;
            }
            if ($field =~ /-/ && $field !~ DOM_SPECIAL_RE) {
                croak "Invalid use of 'L' in range for day-of-month" if $field =~ /\bL\b/;
                croak "Invalid use of 'W' in range for day-of-month" if $field =~ /W-/ || $field =~ /-W/;
            }
            $field = uc($field);
        }

        if ($i == 4) {
            if ($field =~ /^[a-zA-Z]+-[a-zA-Z]+$/) {
                my ($start, $end) = split /-/, $field;
                croak "Invalid month name '$start' in month field" unless $start =~ MONTH_NAME_RE;
                croak "Invalid month name '$end' in month field" unless $end =~ MONTH_NAME_RE;
                my $start_num = $month_map{lc($start)};
                my $end_num = $month_map{lc($end)};
                $field = "$start_num-$end_num";
            } elsif ($field =~ /[a-zA-Z]/) {
                my $original_field = $field;
                my @tokens = split /,/, $field;
                my @normalized_tokens;
                foreach my $token (@tokens) {
                    if ($token =~ /^[a-zA-Z]+$/) {
                        croak "Invalid month name '$token' in month field" unless $token =~ MONTH_NAME_RE;
                        push @normalized_tokens, $month_map{lc($token)};
                    } else {
                        push @normalized_tokens, $token;
                    }
                }
                $field = join ',', @normalized_tokens;
                print STDERR "DEBUG: normalize_expression: MONTH_NAME_RE substitution: '$original_field' -> '$field'\n" if $ENV{Cron_DEBUG};
            }
            croak "Invalid pattern '$field' for month field" unless $field =~ MONTH_PATTERN_RE;
        }

        if ($i == 5) {
            croak "Invalid use of 'W' in day-of-week field" if $field =~ /W/;
            if ($field =~ /[a-zA-Z]/) {
                my $original_field = $field;
                if ($field =~ /^[a-zA-Z]+-[a-zA-Z]+$/) {
                    my ($start, $end) = split /-/, $field;
                    croak "Invalid day name '$start' in day-of-week field" unless $start =~ DOW_NAME_RE;
                    croak "Invalid day name '$end' in day-of-week field" unless $end =~ DOW_NAME_RE;
                    my $start_num = $dow_map{lc($start)};
                    my $end_num = $dow_map{lc($end)};
                    $field = "$start_num-$end_num";
                    print STDERR "DEBUG: normalize_expression: DOW_NAME_RE range substitution: '$original_field' -> '$field'\n" if $ENV{Cron_DEBUG};
                } else {
                    my @tokens = split /,/, $field;
                    my @normalized_tokens;
                    foreach my $token (@tokens) {
                        if ($token =~ /^[a-zA-Z]+$/) {
                            croak "Invalid day name '$token' in day-of-week field" unless $token =~ DOW_NAME_RE;
                            push @normalized_tokens, $dow_map{lc($token)};
                        } else {
                            push @normalized_tokens, $token;
                        }
                    }
                    $field = join ',', @normalized_tokens;
                    print STDERR "DEBUG: normalize_expression: DOW_NAME_RE substitution: '$original_field' -> '$field'\n" if $ENV{Cron_DEBUG};
                }
            }
            croak "Invalid pattern '$field' for dow" unless $field =~ DOW_PATTERN_RE;
            $field = uc($field);
        }

        $fields[$i] = $field;
    }

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

sub to_english {
    my ($self) = @_;
    my ($sec_p, $min_p, $hour_p, $dom_p, $mon_p, $dow_p, $year_p) = @{$self->{patterns}};
    return $self->_match_template($sec_p, $min_p, $hour_p, $dom_p, $mon_p, $dow_p, $year_p);
}

sub _time_phrase {
    my ($self, $min_p, $hour_p, $sec_p) = @_;
    my $sec = $self->_extract_first($sec_p) || 0;
    my $min = $self->_extract_first($min_p) || 0;
    my $hour = $self->_extract_first($hour_p) || 0;
    return $self->_format_time($sec, $min, $hour);
}

sub _extract_first {
    my ($self, $p) = @_;
    return $p->{value} if $p->{pattern_type} eq 'single';
    return $p->{start_value} if $p->{pattern_type} eq 'range';
    return $p->{base}{start_value} || 0 if $p->{pattern_type} eq 'step';
    return 0;
}

sub _format_time {
    my ($self, $sec, $min, $hour) = @_;
    return 'midnight' if $hour == 0 && $min == 0 && $sec == 0;
    return 'noon' if $hour == 12 && $min == 0 && $sec == 0;
    my $h12 = $hour == 0 ? 12 : $hour > 12 ? $hour - 12 : $hour;
    my $ampm = $hour >= 12 ? 'PM' : 'AM';
    return sprintf("%d:%02d:%02d %s", $h12, $min, $sec, $ampm);
}

sub _match_template {
    my ($self, $sec_p, $min_p, $hour_p, $dom_p, $mon_p, $dow_p, $year_p) = @_;

    my $time = $self->_time_phrase($min_p, $hour_p, $sec_p);
    my $is_midnight = (($hour_p->is_single(0)) && ($min_p->is_single(0)) && ($sec_p->is_single(0)));

    # GENERALIZED SPECIALS
    my @specials = (
        [$sec_p, 'wildcard', 'every_minute', {}],
        [$sec_p, 'step', 'every_N_sec', {step => $sec_p->{step}}],
        [$min_p, 'step', 'every_N_min', {step => $min_p->{step}}],
        [$hour_p, 'step', 'every_N_hour', {step => $hour_p->{step}}],
    );
    for (@specials) {
        return fill_template($_->[2], $_->[3]) if $_->[0]{pattern_type} eq $_->[1];
    }

    # PRIORITY + TEMPLATE LOOKUP
    my @fields = qw(second minute hour dom dow month year);
    my ($pattern, $field) = ('', '');
    for my $i (0..6) {
        my $p = ($i==0?$sec_p:$i==1?$min_p:$i==2?$hour_p:$i==3?$dom_p:$i==4?$dow_p:$i==5?$mon_p:$year_p);
        if (my $eng = $p->to_english($fields[$i])) {
            $pattern = $p; $field = $fields[$i]; last;
        }
    }

    my $suffix = $field eq 'dom' && $is_midnight ? '_midnight' : $field eq 'dom' ? '_every' : '';
    my $template_id = $field . '_' . $pattern->{pattern_type} . $suffix;
    my $schedule = $pattern ? fill_template($template_id, $pattern->to_hash) : 'every day';

    return fill_template('schedule_time', {schedule => $schedule, time => $time});
}

sub next {
    my ($self, $epoch) = @_;
    croak "Epoch seconds required (integer)" unless defined $epoch && $epoch =~ /^\d+$/;
    croak "Cron expression must be valid for next()" unless $self->is_valid;

    my $tm = Time::Moment->from_epoch($epoch, offset => $self->{utc_offset});
    my $current = $tm->plus_seconds(1);
    while (1) {
        $current = $self->_next_match($current);
        if ($self->is_match($current)) {
            return $current->epoch;
        }
        $current = $current->plus_seconds(1);
    }
}

sub previous {
    my ($self, $epoch) = @_;
    croak "Epoch seconds required (integer)" unless defined $epoch && $epoch =~ /^\d+$/;
    croak "Cron expression must be valid for previous()" unless $self->is_valid;

    my $tm = Time::Moment->from_epoch($epoch, offset => $self->{utc_offset});
    my $current = $tm->minus_seconds(1);  # Start from previous second
    my $max_iterations = 1_000_000;  # Safety to prevent infinite loops
    my $iterations = 0;

    while ($iterations++ < $max_iterations) {
        $current = $self->_previous_match($current);
        if ($self->is_match($current)) {
            return $current->epoch;
        }
        $current = $current->minus_seconds(1);  # Decrement if no match
    }
    croak "No previous match found after $max_iterations iterations - possible infinite loop";
}

sub _next_match {
    my ($self, $tm) = @_;

    my $year = $tm->year;
    my $month = $tm->month;
    my $dom = $tm->day_of_month;
    my $dow = $self->quartz_dow($tm->day_of_week);
    my $hour = $tm->hour;
    my $minute = $tm->minute;
    my $second = $tm->second;

    my $year_pattern = $self->{patterns}[6];
    while (1) {
        while (!$year_pattern->is_match($year, $tm)) {
            $year++;
        }

        my $month_pattern = $self->{patterns}[4];
        while (1) {
            while (!$month_pattern->is_match($month, $tm)) {
                $month++;
                if ($month > 12) {
                    $month = 1;
                    $year++;
                    $tm = $tm->with_year($year)->with_month($month);
                    last if !$year_pattern->is_match($year, $tm);
                } else {
                    $tm = $tm->with_month($month);
                }
            }

            my $dom_pattern = $self->{patterns}[3];
            my $dow_pattern = $self->{patterns}[5];
            while (1) {
                while (!$dom_pattern->is_match($dom, $tm) || !$dow_pattern->is_match($dow, $tm)) {
                    $dom++;
                    my $days_in_month = $tm->length_of_month;
                    if ($dom > $days_in_month) {
                        $dom = 1;
                        $month++;
                        if ($month > 12) {
                            $month = 1;
                            $year++;
                            $tm = $tm->with_year($year)->with_month($month);
                            last if !$year_pattern->is_match($year, $tm);
                        } else {
                            $tm = $tm->with_month($month);
                        }
                        $days_in_month = $tm->length_of_month;
                    } else {
                        $tm = $tm->with_day_of_month($dom);
                    }
                    $dow = $self->quartz_dow($tm->day_of_week);
                }

                my $hour_pattern = $self->{patterns}[2];
                while (1) {
                    while (!$hour_pattern->is_match($hour, $tm)) {
                        $hour++;
                        if ($hour > 23) {
                            $hour = 0;
                            $dom++;
                            my $days_in_month = $tm->length_of_month;
                            if ($dom > $days_in_month) {
                                $dom = 1;
                                $month++;
                                if ($month > 12) {
                                    $month = 1;
                                    $year++;
                                    $tm = $tm->with_year($year)->with_month($month);
                                    last if !$year_pattern->is_match($year, $tm);
                                } else {
                                    $tm = $tm->with_month($month);
                                }
                                $days_in_month = $tm->length_of_month;
                            } else {
                                $tm = $tm->with_day_of_month($dom);
                            }
                            $dow = $self->quartz_dow($tm->day_of_week);
                            last;
                        }
                    }

                    my $minute_pattern = $self->{patterns}[1];
                    while (1) {
                        while (!$minute_pattern->is_match($minute, $tm)) {
                            $minute++;
                            if ($minute > 59) {
                                $minute = 0;
                                $hour++;
                                last if !$hour_pattern->is_match($hour, $tm);
                            }
                        }

                        my $second_pattern = $self->{patterns}[0];
                        while (1) {
                            while (!$second_pattern->is_match($second, $tm)) {
                                $second++;
                                if ($second > 59) {
                                    $second = 0;
                                    $minute++;
                                    last if !$minute_pattern->is_match($minute, $tm);
                                }
                            }

                            # Full match found
                            return $tm->with_second($second)->with_minute($minute)->with_hour($hour)->with_day_of_month($dom)->with_month($month)->with_year($year);
                        }
                    }
                }
            }
        }
    }
}

# _previous_match similar, but decrementing from coarse to fine
sub _previous_match {
    my ($self, $tm) = @_;

    my $year = $tm->year;
    my $month = $tm->month;
    my $dom = $tm->day_of_month;
    my $dow = $self->quartz_dow($tm->day_of_week);
    my $hour = $tm->hour;
    my $minute = $tm->minute;
    my $second = $tm->second;

    my $year_pattern = $self->{patterns}[6];
    while (1) {
        while (!$year_pattern->is_match($year, $tm)) {
            $year--;
            if ($year < 1970) {
                croak "Year $year is out of range (1970-2199)";
            }
        }

        my $month_pattern = $self->{patterns}[4];
        while (1) {
            while (!$month_pattern->is_match($month, $tm)) {
                $month--;
                if ($month < 1) {
                    $month = 12;
                    $year--;
                    $tm = $tm->with_year($year)->with_month($month);
                    last if !$year_pattern->is_match($year, $tm);
                } else {
                    $tm = $tm->with_month($month);
                }
            }

            my $dom_pattern = $self->{patterns}[3];
            my $dow_pattern = $self->{patterns}[5];
            while (1) {
                while (!$dom_pattern->is_match($dom, $tm) || !$dow_pattern->is_match($dow, $tm)) {
                    $dom--;
                    if ($dom < 1) {
                        $month--;
                        if ($month < 1) {
                            $month = 12;
                            $year--;
                            $tm = $tm->with_year($year)->with_month($month);
                            last if !$year_pattern->is_match($year, $tm);
                        } else {
                            $tm = $tm->with_month($month);
                        }
                        $dom = $tm->length_of_month;
                        $tm = $tm->with_day_of_month($dom);
                    } else {
                        $tm = $tm->with_day_of_month($dom);
                    }
                    $dow = $self->quartz_dow($tm->day_of_week);
                }

                my $hour_pattern = $self->{patterns}[2];
                while (1) {
                    while (!$hour_pattern->is_match($hour, $tm)) {
                        $hour--;
                        if ($hour < 0) {
                            $hour = 23;
                            $dom--;
                            if ($dom < 1) {
                                $month--;
                                if ($month < 1) {
                                    $month = 12;
                                    $year--;
                                    $tm = $tm->with_year($year)->with_month($month);
                                    last if !$year_pattern->is_match($year, $tm);
                                } else {
                                    $tm = $tm->with_month($month);
                                }
                                $dom = $tm->length_of_month;
                                $tm = $tm->with_day_of_month($dom);
                            } else {
                                $tm = $tm->with_day_of_month($dom);
                            }
                            $dow = $self->quartz_dow($tm->day_of_week);
                            last;
                        }
                    }

                    my $minute_pattern = $self->{patterns}[1];
                    while (1) {
                        while (!$minute_pattern->is_match($minute, $tm)) {
                            $minute--;
                            if ($minute < 0) {
                                $minute = 59;
                                $hour--;
                                last if !$hour_pattern->is_match($hour, $tm);
                            }
                        }

                        my $second_pattern = $self->{patterns}[0];
                        while (1) {
                            while (!$second_pattern->is_match($second, $tm)) {
                                $second--;
                                if ($second < 0) {
                                    $second = 59;
                                    $minute--;
                                    last if !$minute_pattern->is_match($minute, $tm);
                                }
                            }

                            # Full match found
                            return $tm->with_second($second)->with_minute($minute)->with_hour($hour)->with_day_of_month($dom)->with_month($month)->with_year($year);
                        }
                    }
                }
            }
        }
    }
}

sub month_range {
    my ($start, $end) = @_;
    return $month_names[$start-1] . '-' . $month_names[$end-1];
}

1;
