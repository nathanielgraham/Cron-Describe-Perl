package Cron::Toolkit::Composer;
use strict;
use warnings;
use Cron::Toolkit::Utils qw(:all);

sub new { bless {}, shift }

sub describe {
    my ($self, $root) = @_;
    my @f = @{ $root->{children} };
    my @type = qw(second minute hour dom month dow year);

    # ------------------------------------------------------------------
    # 1. Build raw phrase list
    # ------------------------------------------------------------------
    my @phrases;
    for my $i (0 .. 6) {
        my $node = $f[$i] or next;
        push @phrases, $self->_phrase_for($node, $type[$i], \@f);
    }

    # ------------------------------------------------------------------
    # 2. Fuse & order
    # ------------------------------------------------------------------
    $self->_fuse_year_month(\@phrases, \@f);
    $self->_fuse_dom_month(\@phrases, \@f);
    $self->_fuse_dow_month(\@phrases, \@f);
    $self->_fuse_time(\@phrases, \@f);

    my $desc = join ' ', grep {$_} @phrases;
    $desc =~ s/\s+/ /g;
    $desc =~ s/^at midnight$/at midnight every day/;
    return $desc || 'every second';
}

# ----------------------------------------------------------------------
# Phrase generators
# ----------------------------------------------------------------------
sub _phrase_for {
    my ($self, $node, $ft, $all) = @_;
    my $t = $node->{type};

    return '' if $t eq 'wildcard' || $t eq 'unspecified';

    # ----- single -----
    if ($t eq 'single') {
        return $self->_single($node->{value}, $ft);
    }

    # ----- range -----
    if ($t eq 'range') {
        my ($s,$e) = map { $_->{value} } @{ $node->{children} };
        return $self->_range($s,$e,$ft);
    }

    # ----- list -----
    if ($t eq 'list') {
        my @parts = map { $self->_phrase_for($_, $ft, $all) } @{ $node->{children} };
        return join_parts(@parts);
    }

    # ----- step -----
    if ($t eq 'step') {
        my $base = $node->{children}[0];
        my $step = $node->{children}[1]{value};
        my $base_str = $base->{type} eq 'wildcard'
            ? '*'
            : $self->_phrase_for($base, $ft, $all);
        return "every $step ".field_unit($ft,$step)." $base_str";
    }

    # ----- special Quartz -----
    if ($t eq 'last')      { return $node->{value} eq 'L' ? 'last day of the month' : "the ".num_to_ordinal($1)." to last day of the month" if $node->{value}=~ /L-(\d+)/; }
    if ($t eq 'lastW')    { return 'last weekday of the month'; }
    if ($t eq 'nth')      { my ($d,$n)=$node->{value}=~ /(\d+)#(\d+)/; return "the ".num_to_ordinal($n)." ".$day_names{$d}." of the month"; }
    if ($t eq 'nearest_weekday') { my ($d)=$node->{value}=~ /(\d+)W/; return "nearest weekday to the ".num_to_ordinal($d); }

    return '';
}

sub _single {
    my ($self,$v,$ft)=@_;
    return $v                     if $ft eq 'second' || $ft eq 'minute' || $ft eq 'hour';
    return num_to_ordinal($v)     if $ft eq 'dom';
    return $month_names{$v}       if $ft eq 'month';
    return $day_names{$v}         if $ft eq 'dow';
    return $v                     if $ft eq 'year';
    return $v;
}
sub _range {
    my ($self,$s,$e,$ft)=@_;
    my $start = $self->_single($s,$ft);
    my $end   = $self->_single($e,$ft);
    return "$start through $end";
}

# ----------------------------------------------------------------------
# Fusion helpers (order matters!)
# ----------------------------------------------------------------------
sub _fuse_year_month {
    my ($self,$p,$f)=@_;
    return unless $p->[6] && $p->[4];
    my $y = $f->[6]{type} eq 'single' ? $f->[6]{value} : $p->[6];
    $p->[4] = fill_template('month_year_single', { month=>$p->[4], year=>$y });
    $p->[6] = '';
}
sub _fuse_dom_month {
    my ($self,$p,$f)=@_;
    return unless $p->[3] && $p->[4];
    $p->[3] = fill_template('dom_special_month_range',
        { dom_desc=>$p->[3], month_range=>$p->[4] });
    $p->[4] = '';
}
sub _fuse_dow_month {
    my ($self,$p,$f)=@_;
    return unless $p->[5] && $p->[4];
    my $dow = $p->[5];
    $dow =~ s/ of the month//;
    $p->[5] = fill_template('dow_nth_month_range',
        { nth_dow=>$dow, month_range=>$p->[4] });
    $p->[4] = '';
}
sub _fuse_time {
    my ($self,$p,$f)=@_;
    my ($s,$m,$h) = map { $f->[$_]{type} eq 'single' ? $f->[$_]{value} : undef } (0,1,2);
    my $time = format_time($s//0,$m//0,$h//0);
    unshift @$p, "at $time" if $time && $time ne '12:00:00 AM';
    unshift @$p, "at midnight" if $h==0 && $m==0 && $s==0;
}
1;
