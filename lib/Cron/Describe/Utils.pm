package Cron::Describe::Utils;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(
  format_time num_to_ordinal field_unit join_parts fill_template is_midnight time_suffix
  %month_map %dow_map @month_names @day_names %nth_names %unit_labels %ordinal_suffix %joiners %templates
);
our %EXPORT_TAGS = (
   constants => [qw(%month_map %dow_map @month_names @day_names %nth_names %unit_labels %ordinal_suffix %joiners %templates)],
   helpers   => [qw(format_time num_to_ordinal field_unit join_parts fill_template is_midnight time_suffix)],
   all       => [@EXPORT_OK]
);

# PARSING MAPS (YOUR GENIUS!)
our %month_map = (
   'jan'       => 1,
   'january'   => 1,
   'feb'       => 2,
   'february'  => 2,
   'mar'       => 3,
   'march'     => 3,
   'apr'       => 4,
   'april'     => 4,
   'may'       => 5,
   'jun'       => 6,
   'june'      => 6,
   'jul'       => 7,
   'july'      => 7,
   'aug'       => 8,
   'august'    => 8,
   'sep'       => 9,
   'september' => 9,
   'oct'       => 10,
   'october'   => 10,
   'nov'       => 11,
   'november'  => 11,
   'dec'       => 12,
   'december'  => 12
);
our %dow_map = (
   'sun'       => 1,
   'sunday'    => 1,
   'mon'       => 2,
   'monday'    => 2,
   'tue'       => 3,
   'tuesday'   => 3,
   'wed'       => 4,
   'wednesday' => 4,
   'thu'       => 5,
   'thursday'  => 5,
   'fri'       => 6,
   'friday'    => 6,
   'sat'       => 7,
   'saturday'  => 7
);

# CORE CONSTANTS
our @month_names = ( undef, 'January', 'February', 'March',   'April',     'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December' );
our @day_names   = ( undef, 'Sunday',  'Monday',   'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday' );
our %nth_names   = ( 1 => 'first', 2 => 'second', 3 => 'third', 4 => 'fourth', 5 => 'fifth' );
our %unit_labels = (
   second => [ 'second',          'seconds' ],
   minute => [ 'minute',          'minutes' ],
   hour   => [ 'hour',            'hours' ],
   dom    => [ 'day',             'days' ],
   month  => [ 'month',           'months' ],
   dow    => [ 'day of the week', 'days of the week' ],
   year   => [ 'year',            'years' ]
);
our %ordinal_suffix = ( 1    => 'st',  2     => 'nd', 3 => 'rd', map { $_ => 'th' } 4 .. 31 );
our %joiners        = ( list => 'and', range => 'through' );

# 37 TEMPLATES
our %templates = (
   every_minute        => 'every minute',
   every_30_minutes    => 'every 30 minutes',
   every_N_sec         => 'every {step} seconds',
   every_N_min         => 'every {step} minutes',
   every_N_hour        => 'every {step} hours',
   dom_single_midnight => 'on the {ordinal} of the month',
   dom_single_every    => 'on the {ordinal} of every month',
   dom_range_midnight  => 'on {start} through {end} of the month',
   dom_range_every     => 'on {start} through {end} of every month',
   dom_list_midnight   => 'on the {list} of the month',
   dom_last_midnight   => 'last day of the month',
   dom_last_every      => 'last day of every month',
   dom_lw_midnight     => 'last weekday of the month',
   dom_lw_every        => 'last weekday of every month',
   dom_nth_last        => '{ordinal} last day of every month',
   dom_step_midnight   => 'every {step} day from {base} of the month',
   dom_step_every      => 'every {step} day from {base} of every month',
   dow_single          => 'every {day}',
   dow_list            => 'on {list}',
   dow_range           => 'on {start} through {end}',
   dow_nth             => '{nth} {day} of every month',
   dow_step            => 'every {step} weekday',
   month_step          => 'every {step} month from {base}',
   year_single         => 'every day in {year}',
   year_range          => 'every day from {start}-{end}',
   year_even           => 'every even year',
   hour_dom_step       => 'every {hour}, every {dom}',
   step_base_range     => 'every {interval} {unit} from {start} to {end}',
   schedule_time       => '{schedule} at {time}',
   every_day           => 'every day'
);

# 5 NEW HELPERS
sub is_midnight { my ( $h, $m, $s ) = @_; return $h == 0 && $m == 0 && $s == 0; }
sub time_suffix { my $h = shift; return $h == 0 ? 'midnight' : $h == 12 ? 'noon' : ''; }

sub ordinal_list {
   join( ', ', map { num_to_ordinal($_) } @_ );
}
sub step_ordinal { my $n = shift; return $n . ( $n == 1 ? 'st' : $n == 2 ? 'nd' : $n == 3 ? 'rd' : 'th' ); }
sub complex_join { join( ', ', @_ ) . ' at {time}'; }

# CORE HELPERS
sub fill_template { my ($id, $data) = @_; my $tpl = $templates{$id} or return ''; $tpl =~ s/{(\w+)}/$data->{$1}||''/ge; return $tpl; }
sub num_to_ordinal { my $n = shift // return ''; return $nth_names{$n} // "$n${ordinal_suffix{$n}//''}"; }
sub field_unit     { my ( $f, $c ) = @_; $c //= 1; my ( $s, $p ) = @{ $unit_labels{$f} }; return $c == 1 ? $s : $p; }

sub join_parts {
   my @p = grep { defined && length } @_;
   return @p == 0 ? '' : @p == 1 ? $p[0] : @p == 2 ? join( " $joiners{range} ", @p ) : join( ', ', @p[ 0 .. $#p - 1 ] ) . " $joiners{list} $p[-1]";
}
sub format_time { my ( $h, $m ) = @_; return '' unless defined $h && defined $m; $h = $h % 12 || 12; return sprintf( '%d:%02d %s', $h, $m, $h % 12 ? ( $h < 12 ? 'AM' : 'PM' ) : 'AM' ); }

1;
