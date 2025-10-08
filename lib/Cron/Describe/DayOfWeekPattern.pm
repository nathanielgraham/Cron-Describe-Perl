package Cron::Describe::DayOfWeekPattern;
use strict;
use warnings;
use Carp qw(croak);
use Time::Moment;
use Cron::Describe::SinglePattern;

sub new {
    my ($class, $value, $min, $max, $field_type) = @_;
    print STDERR "DEBUG: DayOfWeekPattern::new: value='$value', field_type='$field_type'\n";
    croak "Invalid day-of-week pattern '$value' for $field_type" unless $value =~ /^[0-7]#[1-5]$|^[0-7]L$|^(MON|TUE|WED|THU|FRI|SAT|SUN)(,(MON|TUE|WED|THU|FRI|SAT|SUN))*$|^?$/;
    my $self = bless {}, $class;
    $self->{value} = $value;
    $self->{min} = $min;
    $self->{max} = $max;
    $self->{field_type} = $field_type;
    $self->{is_special} = 1 unless $value eq '?';

    if ($value =~ /^([0-7])#([1-5])$/) {
        $self->{pattern_type} = 'nth';
        $self->{day} = $1 eq '7' ? 0 : $1; # Map 7 to 0 for Sunday
        $self->{nth} = $2;
    } elsif ($value =~ /^([0-7])L$/) {
        $self->{pattern_type} = 'last_of_day';
        $self->{day} = $1 eq '7' ? 0 : $1; # Map 7 to 0 for Sunday
    } elsif ($value =~ /^(MON|TUE|WED|THU|FRI|SAT|SUN)(,(MON|TUE|WED|THU|FRI|SAT|SUN))*$/) {
        $self->{pattern_type} = 'list';
        my %day_map = (SUN => 0, MON => 1, TUE => 2, WED => 3, THU => 4, FRI => 5, SAT => 6);
        $self->{sub_patterns} = [ map { Cron::Describe::SinglePattern->new($day_map{$_}, $min, $max, $field_type) } split /,/, $value ];
    } elsif ($value eq '?') {
        $self->{pattern_type} = 'unspecified';
    } elsif ($value =~ /^[0-7]#[6-9]$/) {
        my ($day, $nth) = $value =~ /^([0-7])#([6-9])$/;
        my $day_name = ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')[$day];
        $day_name = 'Sunday' if $day == 7;
        croak "Sixth $day_name is impossible in any month";
    } else {
        croak "Invalid day-of-week pattern '$value' for $field_type";
    }
    print STDERR "DEBUG: DayOfWeekPattern: pattern_type=$self->{pattern_type}, day=" . ($self->{day} // 'undef') . ", nth=" . ($self->{nth} // 'undef') . "\n";
    return $self;
}

sub is_match {
    my ($self, $value, $tm) = @_;
    if ($self->{pattern_type} eq 'nth') {
        my $dow = $tm->day_of_week % 7;
        return 0 unless $dow == $self->{day};
        my $first_day = $tm->with_day_of_month(1);
        my $first_dow = $first_day->day_of_week % 7;
        my $offset = ($self->{day} - $first_dow) % 7;
        $offset += 7 if $offset < 0;
        my $nth_day = $offset + 1 + ($self->{nth} - 1) * 7;
        return $tm->day_of_month == $nth_day && $nth_day <= $tm->length_of_month;
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        my $dow = $tm->day_of_week % 7;
        return 0 unless $dow == $self->{day};
        my $last_day = $tm->length_of_month;
        my $last_dow = $tm->with_day_of_month($last_day)->day_of_week % 7;
        my $offset = ($last_dow - $self->{day}) % 7;
        $offset += 7 if $offset < 0;
        my $target_day = $last_day - $offset;
        return $tm->day_of_month == $target_day && $target_day >= 1;
    } elsif ($self->{pattern_type} eq 'list') {
        foreach my $pattern (@{$self->{sub_patterns}}) {
            return 1 if $pattern->is_match($value, $tm);
        }
    } elsif ($self->{pattern_type} eq 'unspecified') {
        return 1;
    }
    return 0;
}

sub to_hash {
    my $self = shift;
    my $hash = {
        field_type => $self->{field_type},
        pattern_type => $self->{pattern_type},
        min => $self->{min},
        max => $self->{max},
        step => 1
    };
    $hash->{is_special} = $self->{is_special} if defined $self->{is_special};
    if ($self->{pattern_type} eq 'nth') {
        $hash->{day} = $self->{day};
        $hash->{nth} = $self->{nth};
    } elsif ($self->{pattern_type} eq 'last_of_day') {
        $hash->{day} = $self->{day};
    } elsif ($self->{pattern_type} eq 'list') {
        $hash->{sub_patterns} = [ map { $_->to_hash } @{$self->{sub_patterns}} ];
    }
    print STDERR "DEBUG: DayOfWeekPattern::to_hash: " . join(", ", map { "$_=$hash->{$_}" } keys %$hash) . "\n";
    return $hash;
}

1;
