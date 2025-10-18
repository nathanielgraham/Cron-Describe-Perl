package Cron::Describe::Tree::Utils;
use strict;
use warnings;
use Exporter qw(import);
our @EXPORT_OK = qw(format_time num_to_ordinal join_parts fill_template plural_unit %day_names %templates %nth_names);
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );
our %day_names = ( 1 => 'Sunday', 2 => 'Monday', 3 => 'Tuesday', 4 => 'Wednesday', 5 => 'Thursday', 6 => 'Friday', 7 => 'Saturday' );
our %nth_names = ( 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', 5 => 'fifth' );
our %templates = (
    every_N_sec => 'every {step} seconds',
    every_N_min => 'every {step} minutes',
    step_range => 'every {step} minutes from {start} to {end} past {hour}',
    dow_single => 'every {day}',
    dom_single_every => 'on the {ordinal} of every month',
    dom_range_every => 'the {start} through {end} of every month',
    # FIXED #2: TEMPLATES
    dow_list => 'every {list}',
    dom_last => 'the last day of every month',
    dom_lw => 'the last weekday of every month',
    dow_nth => 'the {nth} {day} of every month',
    year_in => 'every day in {year}',
);
sub format_time {
    my ($s, $m, $h) = @_;
    return '' unless defined $h && defined $m && defined $s && $h =~ /^\d+$/ && $m =~ /^\d+$/ && $s =~ /^\d+$/;
    $h = ($h % 12) || 12;
    my $ampm = ($h >= 12) ? 'PM' : 'AM';
    return sprintf '%d:%02d:%02d %s', $h, $m, $s, $ampm;
}
sub fill_template { my ($id, $data) = @_; my $tpl = $templates{$id} or return ''; $tpl =~ s/{(\w+)}/$data->{$1}||''/ge; return $tpl; }
sub num_to_ordinal { my $n = shift // return ''; return $nth_names{$n} || $n . ($n==1?'st':$n==2?'nd':$n==3?'rd':'th'); }
sub join_parts { my @p = grep { defined && length } @_; return @p == 0 ? '' : @p == 1 ? $p[0] : @p == 2 ? "$p[0] and $p[1]" : join(', ', @p[0..$#p-2]) . ' and ' . $p[-1]; }
sub plural_unit { my ($field_type, $step) = @_; return $field_type . ($step == 1 ? '' : 's'); }
1;
