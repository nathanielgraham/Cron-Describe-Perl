package Cron::Describe::DayOfWeek;
use strict;
use warnings;
use parent 'Cron::Describe::Field';
use Carp qw(croak);
use DateTime;

sub new {
    my ($class, %args) = @_;
    $args{field_type} = 'dow';
    $args{range} = [0, 7];
    my $self = $class->SUPER::new(%args);
    print "DEBUG: DayOfWeek.pm loaded (mtime: ", (stat(__FILE__))[9], ") for type dow\n" if $Cron::Describe::Quartz::DEBUG;
    bless $self, $class;
    return $self;
}

sub parse {
    my ($self, $value) = @_;
    print "DEBUG: Parsing field dow with value ", (defined $value ? "'$value'" : 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    
    if (!defined $value || $value eq '') {
        $self->{pattern_type} = 'error';
        print "DEBUG: No pattern matched for dow with undefined or empty value, marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    my %dow_map = (
        SUN => 0, MON => 1, TUE => 2, WED => 3, THU => 4, FRI => 5, SAT => 6
    );
    if ($value =~ /,/) {
        my @parts = split /,/, $value;
        print "DEBUG: Parsing list for dow, parts=[", join(", ", @parts), "]\n" if $Cron::Describe::Quartz::DEBUG;
        my @sub_patterns;
        for my $part (@parts) {
            print "DEBUG: Parsing single part '$part' for dow\n" if $Cron::Describe::Quartz::DEBUG;
            my $mapped_value = exists $dow_map{$part} ? $dow_map{$part} : $part;
            my $sub_field = Cron::Describe::Field->new(
                field_type => 'dow',
                value => $mapped_value,
                range => [0, 7]
            );
            if (($sub_field->{pattern_type} || '') eq 'error') {
                $self->{pattern_type} = 'error';
                print "DEBUG: No pattern matched for dow with value '$part', marking as error\n" if $Cron::Describe::Quartz::DEBUG;
                return;
            }
            my $sub_pattern = {
                field_type => 'dow',
                pattern_type => $sub_field->{pattern_type},
            };
            $sub_pattern->{value} = $sub_field->{value} if exists $sub_field->{value};
            $sub_pattern->{min_value} = $sub_field->{min_value} if exists $sub_field->{min_value};
            $sub_pattern->{max_value} = $sub_field->{max_value} if exists $sub_field->{max_value};
            $sub_pattern->{start_value} = $sub_field->{start_value} if exists $sub_field->{start_value};
            $sub_pattern->{step} = $sub_field->{step} if exists $sub_field->{step};
            push @sub_patterns, $sub_pattern;
            print "DEBUG: Added sub_pattern for dow: type=$sub_pattern->{pattern_type}, ",
                  (exists $sub_pattern->{value} ? "value=$sub_pattern->{value}, " : ""),
                  (exists $sub_pattern->{min_value} ? "min_value=$sub_pattern->{min_value}, " : ""),
                  (exists $sub_pattern->{max_value} ? "max_value=$sub_pattern->{max_value}, " : ""),
                  (exists $sub_pattern->{start_value} ? "start_value=$sub_pattern->{start_value}, " : ""),
                  (exists $sub_pattern->{step} ? "step=$sub_pattern->{step}" : ""), "\n" if $Cron::Describe::Quartz::DEBUG;
        }
        $self->{pattern_type} = 'list';
        $self->{sub_patterns} = \@sub_patterns;
        print "DEBUG: Matched list for dow, sub_patterns count=", scalar(@sub_patterns), "\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if (exists $dow_map{$value}) {
        $value = $dow_map{$value};
        print "DEBUG: Mapped dow name '$value' to numeric\n" if $Cron::Describe::Quartz::DEBUG;
    }
    if ($value eq '?' || $value eq '*') {
        $self->{pattern_type} = $value eq '?' ? 'unspecified' : 'wildcard';
        print "DEBUG: Matched ", ($value eq '?' ? 'unspecified' : 'wildcard'), " for dow\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value =~ /^(\d+)#(\d+)$/) {
        my ($day, $nth) = ($1 + 0, $2 + 0);
        print "DEBUG: Testing $day#$nth for dow, day range=[0,7], nth range=[1,5]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($day >= 0 && $day <= 7 && $nth >= 1 && $nth <= 5) {
            $self->{pattern_type} = 'nth';
            $self->{day} = $day;
            $self->{nth} = $nth;
            $self->{is_special} = 1;
            print "DEBUG: Matched nth for dow, day=$day, nth=$nth\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Invalid $day#$nth for dow, out of range\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /^(\d+)L$/) {
        my $day = $1 + 0;
        print "DEBUG: Testing $day"."L for dow, range=[0,7]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($day >= 0 && $day <= 7) {
            $self->{pattern_type} = 'last_of_day';
            $self->{day} = $day;
            $self->{is_special} = 1;
            print "DEBUG: Matched last_of_day for dow, day=$day\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Invalid $day"."L for dow, out of range [0,7]\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    $self->SUPER::parse($value);
}

sub is_match {
    my ($self, $date) = @_;
    croak "Expected Time::Moment object, got '$date'" unless ref($date) eq 'Time::Moment';
    print "DEBUG: is_match for dow, pattern_type=", ($self->{pattern_type} // 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    return 0 if ($self->{pattern_type} || '') eq 'error';
    if (($self->{pattern_type} || '') eq 'nth') {
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => 1,
            time_zone => 'UTC'
        );
        my $dow = $dt->day_of_week;
        $dow = 0 if $dow == 7;
        my $target_day = $self->{day} // 0;
        my $first_occurrence = $target_day >= $dow ? $target_day - $dow + 1 : 8 - $dow + $target_day;
        my $nth_day = $first_occurrence + ($self->{nth} - 1) * 7;
        my $result = $date->day_of_month == $nth_day && $nth_day <= $date->length_of_month;
        print "DEBUG: DOW nth match, day=$self->{day}, nth=$self->{nth}, first_occurrence=$first_occurrence, nth_day=$nth_day, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'last_of_day') {
        my $last_day = $date->length_of_month;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $last_day,
            time_zone => 'UTC'
        );
        while ($dt->day_of_week != ($self->{day} // 0) && $dt->day_of_month >= 1) {
            $dt = $dt->subtract(days => 1);
        }
        my $result = $date->day_of_month == $dt->day_of_month;
        print "DEBUG: DOW last_of_day match, day=$self->{day}, target_day=", $dt->day_of_month, ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'list') {
        for my $sub_pattern (@{$self->{sub_patterns} || []}) {
            my $sub_field = Cron::Describe::Field->new(
                field_type => 'dow',
                %$sub_pattern,
                range => [0, 7]
            );
            my $result = $sub_field->is_match($date->day_of_week % 7);
            print "DEBUG: DOW list sub_pattern match, type=$sub_pattern->{pattern_type}, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
            return 1 if $result;
        }
        print "DEBUG: DOW list match, no sub_patterns matched\n" if $Cron::Describe::Quartz::DEBUG;
        return 0;
    }
    my $result = $self->SUPER::is_match($date->day_of_week % 7);
    print "DEBUG: DOW default match, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
    return $result;
}

1;
