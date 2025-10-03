package Cron::Describe::DayOfMonth;
use strict;
use warnings;
use parent 'Cron::Describe::Field';
use Carp qw(croak);
use DateTime;

sub new {
    my ($class, %args) = @_;
    $args{field_type} = 'dom';
    $args{range} = [1, 31];
    my $self = $class->SUPER::new(%args);
    print "DEBUG: DayOfMonth.pm loaded (mtime: ", (stat(__FILE__))[9], ") for type dom\n" if $Cron::Describe::Quartz::DEBUG;
    bless $self, $class;
    return $self;
}

sub parse {
    my ($self, $value) = @_;
    print "DEBUG: Parsing field dom with value ", (defined $value ? "'$value'" : 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    
    if (!defined $value || $value eq '') {
        $self->{pattern_type} = 'error';
        print "DEBUG: No pattern matched for dom with undefined or empty value, marking as error\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value eq '?' || $value eq '*') {
        $self->{pattern_type} = $value eq '?' ? 'unspecified' : 'wildcard';
        print "DEBUG: Matched ", ($value eq '?' ? 'unspecified' : 'wildcard'), " for dom\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value eq 'L') {
        $self->{pattern_type} = 'last';
        $self->{offset} = 0;
        $self->{is_special} = 1;
        print "DEBUG: Matched last for dom, offset=0\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value eq 'LW') {
        $self->{pattern_type} = 'last_weekday';
        $self->{offset} = 0;
        $self->{is_special} = 1;
        print "DEBUG: Matched last_weekday for dom\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    if ($value =~ /^L-(\d+)$/) {
        my $offset = $1 + 0;
        print "DEBUG: Testing L-$offset for dom, range=[0,30]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($offset >= 0 && $offset <= 30) {
            $self->{pattern_type} = 'last';
            $self->{offset} = $offset;
            $self->{is_special} = 1;
            print "DEBUG: Matched last for dom, offset=$offset\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Invalid L-$offset for dom, out of range [0,30]\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /^(\d+)W$/) {
        my $day = $1 + 0;
        print "DEBUG: Testing $day"."W for dom, range=[1,31]\n" if $Cron::Describe::Quartz::DEBUG;
        if ($day >= 1 && $day <= 31) {
            $self->{pattern_type} = 'nearest_weekday';
            $self->{day} = $day;
            $self->{is_special} = 1;
            print "DEBUG: Matched nearest_weekday for dom, day=$day\n" if $Cron::Describe::Quartz::DEBUG;
            return;
        } else {
            print "DEBUG: Invalid $day"."W for dom, out of range [1,31]\n" if $Cron::Describe::Quartz::DEBUG;
        }
    }
    if ($value =~ /,/) {
        my @parts = split /,/, $value;
        print "DEBUG: Parsing list for dom, parts=[", join(", ", @parts), "]\n" if $Cron::Describe::Quartz::DEBUG;
        my @sub_patterns;
        for my $part (@parts) {
            print "DEBUG: Parsing single part '$part' for dom\n" if $Cron::Describe::Quartz::DEBUG;
            my $sub_field = Cron::Describe::Field->new(
                field_type => 'dom',
                value => $part,
                range => [1, 31]
            );
            if (($sub_field->{pattern_type} || '') eq 'error') {
                $self->{pattern_type} = 'error';
                print "DEBUG: No pattern matched for dom with value '$part', marking as error\n" if $Cron::Describe::Quartz::DEBUG;
                return;
            }
            my $sub_pattern = {
                field_type => 'dom',
                pattern_type => $sub_field->{pattern_type},
            };
            $sub_pattern->{value} = $sub_field->{value} if exists $sub_field->{value};
            $sub_pattern->{min_value} = $sub_field->{min_value} if exists $sub_field->{min_value};
            $sub_pattern->{max_value} = $sub_field->{max_value} if exists $sub_field->{max_value};
            $sub_pattern->{start_value} = $sub_field->{start_value} if exists $sub_field->{start_value};
            $sub_pattern->{step} = $sub_field->{step} if exists $sub_field->{step};
            push @sub_patterns, $sub_pattern;
            print "DEBUG: Added sub_pattern for dom: type=$sub_pattern->{pattern_type}, ",
                  (exists $sub_pattern->{value} ? "value=$sub_pattern->{value}, " : ""),
                  (exists $sub_pattern->{min_value} ? "min_value=$sub_pattern->{min_value}, " : ""),
                  (exists $sub_pattern->{max_value} ? "max_value=$sub_pattern->{max_value}, " : ""),
                  (exists $sub_pattern->{start_value} ? "start_value=$sub_pattern->{start_value}, " : ""),
                  (exists $sub_pattern->{step} ? "step=$sub_pattern->{step}" : ""), "\n" if $Cron::Describe::Quartz::DEBUG;
        }
        $self->{pattern_type} = 'list';
        $self->{sub_patterns} = \@sub_patterns;
        print "DEBUG: Matched list for dom, sub_patterns count=", scalar(@sub_patterns), "\n" if $Cron::Describe::Quartz::DEBUG;
        return;
    }
    $self->SUPER::parse($value);
}

sub is_match {
    my ($self, $date) = @_;
    croak "Expected Time::Moment object, got '$date'" unless ref($date) eq 'Time::Moment';
    print "DEBUG: is_match for dom, pattern_type=", ($self->{pattern_type} // 'undef'), "\n" if $Cron::Describe::Quartz::DEBUG;
    return 0 if ($self->{pattern_type} || '') eq 'error';
    if (($self->{pattern_type} || '') eq 'last') {
        my $last_day = $date->length_of_month;
        my $target_day = $last_day - ($self->{offset} // 0);
        my $result = $date->day_of_month == $target_day && $target_day >= 1;
        print "DEBUG: DOM last match, last_day=$last_day, target_day=$target_day, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'last_weekday') {
        my $last_day = $date->length_of_month;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $last_day,
            time_zone => 'UTC'
        );
        while ($dt->day_of_week == 0 || $dt->day_of_week == 6) {
            $dt = $dt->subtract(days => 1);
        }
        my $result = $date->day_of_month == $dt->day_of_month;
        print "DEBUG: DOM last_weekday match, last_day=$last_day, target_day=", $dt->day_of_month, ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'nearest_weekday') {
        my $target_day = $self->{day} // 0;
        my $last_day = $date->length_of_month;
        print "DEBUG: DOM nearest_weekday match, target_day=$target_day, last_day=$last_day\n" if $Cron::Describe::Quartz::DEBUG;
        return 0 if $target_day > $last_day;
        my $dt = DateTime->new(
            year => $date->year,
            month => $date->month,
            day => $target_day,
            time_zone => 'UTC'
        );
        my $dow = $dt->day_of_week;
        if ($dow == 0 || $dow == 6) {
            my $offset = $dow == 6 ? -1 : 1;
            $dt = $dt->add(days => $offset);
            while ($dt->day_of_month > $last_day || $dt->day_of_week == 0 || $dt->day_of_week == 6) {
                $dt = $dt->add(days => $offset > 0 ? -1 : 1);
            }
        }
        my $result = $date->day_of_month == $dt->day_of_month;
        print "DEBUG: DOM nearest_weekday match, target_day=$target_day, adjusted_day=", $dt->day_of_month, ", result=$result\n" if $Cron::Describe::Quartz::DEBUG;
        return $result;
    }
    if (($self->{pattern_type} || '') eq 'list') {
        for my $sub_pattern (@{$self->{sub_patterns} || []}) {
            my $sub_field = Cron::Describe::Field->new(
                field_type => 'dom',
                %$sub_pattern,
                range => [1, 31]
            );
            my $result = $sub_field->is_match($date->day_of_month);
            print "DEBUG: DOM list sub_pattern match, type=$sub_pattern->{pattern_type}, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
            return 1 if $result;
        }
        print "DEBUG: DOM list match, no sub_patterns matched\n" if $Cron::Describe::Quartz::DEBUG;
        return 0;
    }
    my $result = $self->SUPER::is_match($date->day_of_month);
    print "DEBUG: DOM default match, result=$result\n" if $Cron::Describe::Quartz::DEBUG;
    return $result;
}

1;
