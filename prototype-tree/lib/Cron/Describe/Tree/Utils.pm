package Cron::Describe::Tree::Utils;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(format_time num_to_ordinal join_parts fill_template plural_unit %day_names %templates);
our %EXPORT_TAGS = ( all => [@EXPORT_OK] );

our %day_names = ( 1 => 'Sunday', 2 => 'Monday', 3 => 'Tuesday', 4 => 'Wednesday', 5 => 'Thursday', 6 => 'Friday', 7 => 'Saturday' );

our %templates = (
   every_N_sec => 'every {step} seconds',
   every_N_min => 'every {step} minutes',
   dom_range_every => 'on the {start} through {end} of every month',
   dow_list => 'on {list}',
   dom_last => 'last day of every month',
   dom_lw => 'last weekday of every month',
   dow_nth => '{nth} {day} of every month',
   year_in => 'in {year}',
   every_day => 'every day',
   step_range => 'every {step} minutes from {start} to {end} past {hour}',
);

sub fill_template { my ($id, $data) = @_; my $tpl = $templates{$id} or return ''; $tpl =~ s/{(\w+)}/$data->{$1}||''/ge; return $tpl; }
sub num_to_ordinal { my $n = shift // return ''; return $n . ($n==1?'st':$n==2?'nd':$n==3?'rd':'th'); }
sub join_parts { my @p = grep { defined && length } @_; return @p == 0 ? '' : @p == 1 ? $p[0] : @p == 2 ? "$p[0] and $p[1]" : join(', ', @p[0..$#p-1]) . " and $p[-1]"; }
sub format_time { my ($s, $m, $h) = @_; return '' unless defined $h && defined $m && defined $s; $h = $h % 12 || 12; return sprintf '%d:%02d:%02d %s', $h, $m, $s, $h % 12 ? ($h < 12 ? 'AM' : 'PM') : 'AM'; }
sub plural_unit { my ($field_type, $step) = @_; return $field_type . ($step == 1 ? '' : 's'); }

1;
