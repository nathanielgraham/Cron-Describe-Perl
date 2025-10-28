package Cron::Toolkit::Matcher;
use strict;
use warnings;
use Time::Moment;
use Cron::Toolkit::Utils qw(%LIMITS @FIELDS);
use List::Util qw(min max);

sub new {
    my ($class, %args) = @_;
    return bless {
        tree       => $args{tree},
        utc_offset => $args{utc_offset} // 0,
        owner      => $args{owner},
    }, $class;
}

sub next {
    my ($self, $epoch_seconds) = @_;
    $epoch_seconds //= time;
    return $self->_find_next_or_previous($epoch_seconds, 1);
}

sub previous {
    my ($self, $epoch_seconds) = @_;
    $epoch_seconds //= time;
    return $self->_find_next_or_previous($epoch_seconds, -1);
}

sub _find_next_or_previous {
    my ($self, $epoch_seconds, $direction) = @_;
    my $begin_epoch = $self->{owner}->begin_epoch // 0;
    my $end_epoch   = $self->{owner}->end_epoch;

    my $clamped = $direction > 0
        ? max($epoch_seconds, $begin_epoch)
        : min($epoch_seconds, $end_epoch // $epoch_seconds);

    return undef if $direction > 0 && $clamped > $end_epoch;
    return undef if $direction < 0 && $clamped < $begin_epoch;

    my $tm = Time::Moment->from_epoch($clamped)
        ->with_offset_same_instant($self->{utc_offset});

    $tm = $direction > 0 ? $tm->plus_seconds(1) : $tm->minus_seconds(1);

    my $iter = 0;
    my $max_iter = 1_000_000;  # Allow long gaps

    while ($iter++ < $max_iter) {
        my $epoch = $tm->epoch;

        if ($direction > 0 && $end_epoch && $epoch > $end_epoch) { last; }
        if ($direction < 0 && $epoch < $begin_epoch) { last; }

        return $epoch if $self->match($epoch);

        my @c = $self->_time_components($tm);
        my @new_c = $direction > 0
            ? $self->_increment_time(\@c)
            : $self->_decrement_time(\@c);

        last unless @new_c;
        $tm = $self->_tm_from_components(\@new_c);
        last unless $tm;
    }
    return undef;
}

sub match {
    my ($self, $epoch_seconds) = @_;
    return 0 unless defined $epoch_seconds;

    my $tm = Time::Moment->from_epoch($epoch_seconds)
        ->with_offset_same_instant($self->{utc_offset});

    my @nodes = @{$self->{tree}{children}};

    for my $i (0 .. $#FIELDS) {
        my $node = $nodes[$i] or next;
        next if $node->{type} eq 'wildcard' || $node->{type} eq 'unspecified';
        next if $i == 3 && $nodes[5]{type} ne 'unspecified';
        next if $i == 5 && $nodes[3]{type} ne 'unspecified';

        my $value = $self->_field_value($tm, $FIELDS[$i]);
        my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new(value => $value, tm => $tm);
        return 0 unless $node->traverse($visitor);
    }
    return 1;
}

sub _field_value {
    my ($self, $tm, $type) = @_;
    return $tm->second if $type eq 'second';
    return $tm->minute if $type eq 'minute';
    return $tm->hour if $type eq 'hour';
    return $tm->day_of_month if $type eq 'dom';
    return $tm->month if $type eq 'month';
    return ($tm->day_of_week % 7) if $type eq 'dow';
    return $tm->year if $type eq 'year';
}

sub _time_components {
    my ($self, $tm) = @_;
    return (
        $tm->second,
        $tm->minute,
        $tm->hour,
        $tm->day_of_month,
        $tm->month,
        ($tm->day_of_week % 7),
        $tm->year,
    );
}

sub _tm_from_components {
    my ($self, $c) = @_;
    eval {
        Time::Moment->new(
            year   => $c->[6],
            month  => $c->[4],
            day    => $c->[3],
            hour   => $c->[2],
            minute => $c->[1],
            second => $c->[0],
        );
    } // undef;
}

sub _increment_time {
    my ($self, $c) = @_;
    my @nodes = @{$self->{tree}{children}};
    my $candidate_tm = $self->_tm_from_components($c) // return ();

    for my $i (0 .. $#FIELDS) {
        my $node = $nodes[$i] or next;
        next if $node->{type} eq 'unspecified';

        my $next_v = $self->_next_allowed_value($i, $c->[$i], $candidate_tm);
        if (defined $next_v) {
            $c->[$i] = $next_v;
            for my $j (0 .. $i - 1) {
                $c->[$j] = $self->_lowest_allowed($j, $candidate_tm);
            }
            return @$c;
        } else {
            $c->[$i] = $self->_lowest_allowed($i, $candidate_tm);
        }
    }
    return ();
}

sub _decrement_time {
    my ($self, $c) = @_;
    my @nodes = @{$self->{tree}{children}};
    my $candidate_tm = $self->_tm_from_components($c) // return ();

    for my $i (0 .. $#FIELDS) {
        my $node = $nodes[$i] or next;
        next if $node->{type} eq 'unspecified';

        my $prev_v = $self->_prev_allowed_value($i, $c->[$i], $candidate_tm);
        if (defined $prev_v) {
            $c->[$i] = $prev_v;
            for my $j (0 .. $i - 1) {
                $c->[$j] = $self->_highest_allowed($j, $candidate_tm);
            }
            return @$c;
        } else {
            $c->[$i] = $self->_highest_allowed($i, $candidate_tm);
        }
    }
    return ();
}

sub _next_allowed_value {
    my ($self, $i, $current, $candidate_tm) = @_;
    my $node = $self->{tree}{children}[$i];
    my $field = $FIELDS[$i];
    my ($min, $max) = @{$LIMITS{$field}};
    $max = $candidate_tm->length_of_month if $field eq 'dom';

    for my $v ($current + 1 .. $max) {
        my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new(value => $v, tm => $candidate_tm);
        return $v if $node->traverse($visitor);
    }
    return undef;
}

sub _prev_allowed_value {
    my ($self, $i, $current, $candidate_tm) = @_;
    my $node = $self->{tree}{children}[$i];
    my $field = $FIELDS[$i];
    my ($min, $max) = @{$LIMITS{$field}};
    $max = $candidate_tm->length_of_month if $field eq 'dom';

    for my $v (reverse $min .. $current - 1) {
        my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new(value => $v, tm => $candidate_tm);
        return $v if $node->traverse($visitor);
    }
    return undef;
}

sub _lowest_allowed {
    my ($self, $i, $candidate_tm) = @_;
    my $node = $self->{tree}{children}[$i];
    my $field = $FIELDS[$i];
    my ($min, $max) = @{$LIMITS{$field}};
    $max = $candidate_tm->length_of_month if $field eq 'dom';

    for my $v ($min .. $max) {
        my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new(value => $v, tm => $candidate_tm);
        return $v if $node->traverse($visitor);
    }
    return undef;
}

sub _highest_allowed {
    my ($self, $i, $candidate_tm) = @_;
    my $node = $self->{tree}{children}[$i];
    my $field = $FIELDS[$i];
    my ($min, $max) = @{$LIMITS{$field}};
    $max = $candidate_tm->length_of_month if $field eq 'dom';

    for my $v (reverse $min .. $max) {
        my $visitor = Cron::Toolkit::Visitor::MatchVisitor->new(value => $v, tm => $candidate_tm);
        return $v if $node->traverse($visitor);
    }
    return undef;
}

1;
