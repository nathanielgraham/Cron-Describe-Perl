package Cron::Describe::DayOfWeek;

use strict;
use warnings;
use base 'Cron::Describe::Field';

sub parse {
    my $self = shift;
    my $value = $self->{value} // '*';
    print STDERR "DEBUG: DayOfWeek.pm loaded (mtime: " . (stat(__FILE__))[9] . ") parsing value=$value\n";
    eval {
        if ($value =~ /^(\d+)#(\d+)$/) {
            $self->{parsed} = [{ type => 'nth', day => $1, nth => $2 }];
            die "Invalid nth: $2 (max 5)" if $2 < 1 || $2 > 5;
            die "Invalid day: $1" if $1 < 0 || $1 > 7;
            print STDERR "DEBUG: Parsed nth: day=$1, nth=$2\n";
        } elsif ($value =~ /^(\d+)L$/) {
            $self->{parsed} = [{ type => 'last_of_day', day => $1 }];
            die "Invalid day: $1" if $1 < 0 || $1 > 7;
            print STDERR "DEBUG: Parsed last_of_day: day=$1\n";
        } else {
            $self->SUPER::parse();
        }
    };
    if ($@) {
        warn "Parse error in DayOfWeek: $@";
        $self->{parsed} = [{ type => '*' }]; # Fallback to wildcard
        print STDERR "DEBUG: Fallback to wildcard for DayOfWeek\n";
    }
    return $self; # Ensure blessed object return
}

sub matches {
    my ($self, $time_parts) = @_;
    my $dow = $time_parts->{dow};
    my $dom = $time_parts->{dom};
    print STDERR "DEBUG: Checking DayOfWeek match: dow=$dow, dom=$dom\n";
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'nth') {
            my $occurrence = int(($dom - 1) / 7) + 1;
            if ($dow == $struct->{day} && $occurrence == $struct->{nth}) {
                print STDERR "DEBUG: DayOfWeek matches nth: day=$struct->{day}, occurrence=$occurrence\n";
                return 1;
            }
        } elsif ($struct->{type} eq 'last_of_day') {
            my $occurrence = int(($dom - 1) / 7) + 1;
            my $dim = Cron::Describe::_days_in_month($time_parts->{month}, $time_parts->{year});
            my $max_occurrence = int(($dim - 1) / 7) + 1;
            if ($dow == $struct->{day} && $occurrence == $max_occurrence) {
                print STDERR "DEBUG: DayOfWeek matches last_of_day: day=$struct->{day}, occurrence=$occurrence\n";
                return 1;
            }
        } else {
            return $self->SUPER::matches($time_parts);
        }
    }
    print STDERR "DEBUG: DayOfWeek does not match\n";
    return 0;
}

sub to_english {
    my $self = shift;
    print STDERR "DEBUG: Generating to_english for DayOfWeek\n";
    my @phrases;
    my %dow_names = (0=>'0', 1=>'1', 2=>'2', 3=>'3', 4=>'4', 5=>'5', 6=>'6', 7=>'0');
    for my $struct (@{$self->{parsed}}) {
        if ($struct->{type} eq 'nth') {
            my $nth = $struct->{nth} == 1 ? 'first' : $struct->{nth} == 2 ? 'second' : $struct->{nth} == 3 ? 'third' : $struct->{nth} == 4 ? 'fourth' : 'fifth';
            push @phrases, "$nth $dow_names{$struct->{day}}";
            print STDERR "DEBUG: DayOfWeek nth: $nth $dow_names{$struct->{day}}\n";
        } elsif ($struct->{type} eq 'last_of_day') {
            push @phrases, "last $dow_names{$struct->{day}}";
            print STDERR "DEBUG: DayOfWeek last_of_day: last $dow_names{$struct->{day}}\n";
        } elsif ($struct->{type} eq 'single') {
            push @phrases, $dow_names{$struct->{min}};
            print STDERR "DEBUG: DayOfWeek single: $dow_names{$struct->{min}}\n";
        } else {
            push @phrases, "every day-of-week";
            print STDERR "DEBUG: DayOfWeek wildcard: every day-of-week\n";
        }
    }
    my $result = join(', ', @phrases) || "every day-of-week";
    print STDERR "DEBUG: DayOfWeek to_english result: $result\n";
    return $result;
}

1;
