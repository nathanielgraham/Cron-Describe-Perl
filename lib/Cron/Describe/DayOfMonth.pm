package Cron::Describe::DayOfMonth;

use strict;
use warnings;
use base 'Cron::Describe::Field';

sub parse {
    my $self = shift;
    my $value = $self->{value} // '*';
    print STDERR "DEBUG: DayOfMonth.pm loaded (mtime: " . (stat(__FILE__))[9] . ") parsing value=$value\n";
    eval {
        if ($value =~ /^L(?:-(\d+))?$/) {
            my $offset = $1 // 0;
            die "Invalid offset: $offset" if $offset > 30;
            $self->{parsed} = [{ type => 'last', offset => $offset }];
            print STDERR "DEBUG: Parsed last: offset=$offset\n";
        } elsif ($value =~ /^(\d+)W$/) {
            my $day = $1;
            die "Invalid day: $day" if $day < 1 || $day > 31;
            $self->{parsed} = [{ type => 'nearest_weekday', day => $day }];
            print STDERR "DEBUG: Parsed nearest_weekday: day=$day\n";
        } else {
            $self->SUPER::parse();
        }
    };
    if ($@) {
        warn "Parse error in DayOfMonth: $@";
        $self->{parsed} = [{ type => '*' }]; # Fallback to wildcard
        print STDERR "DEBUG: Fallback to wildcard for DayOfMonth\n";
    }
    return $self; # Ensure blessed object return
}

sub matches {
    my ($self, $time_parts) = @_;
    my $dom = $time_parts->{dom};
    print STDERR "DEBUG: Checking DayOfMonth match: dom=$dom\n";
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'last') {
            my $last_day = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
            if ($dom == $last_day - $struct->{offset}) {
                print STDERR "DEBUG: DayOfMonth matches last: dom=$dom, last_day=$last_day, offset=$struct->{offset}\n";
                return 1;
            }
        } elsif ($struct->{type} eq 'nearest_weekday') {
            my $target_day = $struct->{day};
            my $dow = Cron::Describe::_dow_of_date($time_parts->{year}, $time_parts->{month}, $target_day);
            if ($dow == 6) { $target_day -= 1; }  # Sat -> Fri
            elsif ($dow == 0) { $target_day += 1; }  # Sun -> Mon
            my $dim = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
            if ($target_day < 1 || $target_day > $dim) {
                print STDERR "DEBUG: DayOfMonth does not match nearest_weekday: target_day=$target_day out of bounds\n";
                return 0;
            }
            if ($dom == $target_day) {
                print STDERR "DEBUG: DayOfMonth matches nearest_weekday: dom=$dom, target_day=$target_day\n";
                return 1;
            }
        } else {
            return $self->SUPER::matches($time_parts);
        }
    }
    print STDERR "DEBUG: DayOfMonth does not match\n";
    return 0;
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english for DayOfMonth\n";
    my @phrases;
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'last') {
            push @phrases, $struct->{offset} ? "last day minus $struct->{offset}" : "last day";
            print STDERR "DEBUG: DayOfMonth last: " . ($struct->{offset} ? "last day minus $struct->{offset}" : "last day") . "\n";
        } elsif ($struct->{type} eq 'nearest_weekday') {
            push @phrases, "nearest weekday to the $struct->{day}";
            print STDERR "DEBUG: DayOfMonth nearest_weekday: nearest weekday to the $struct->{day}\n";
        } else {
            my $base = $self->SUPER::to_english();
            print STDERR "DEBUG: DayOfMonth base: $base\n";
            return $base; # Avoid duplication
        }
    }
    my $result = join(', ', @phrases) || "every day-of-month";
    print STDERR "DEBUG: DayOfMonth to_english result: $result\n";
    return $result;
}

1;
