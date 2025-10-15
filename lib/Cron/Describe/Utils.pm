package Cron::Describe::Utils;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(
    format_time num_to_ordinal field_unit join_parts
    %month_map %dow_map @month_names @day_names %nth_names %time_specials %unit_labels
    %ordinal_suffix %day_ordinal %prepositions %joiners %frequency_words
);

our %EXPORT_TAGS = (
    constants => [qw(%month_map %dow_map @month_names @day_names %nth_names %time_specials %unit_labels %ordinal_suffix %day_ordinal %prepositions %joiners %frequency_words)],
    helpers   => [qw(format_time num_to_ordinal field_unit join_parts)],
    all       => [@EXPORT_OK]
);

# Constants: Maps (name -> number)
our %month_map = (
    'jan' => 1, 'january' => 1,
    'feb' => 2, 'february' => 2,
    'mar' => 3, 'march' => 3,
    'apr' => 4, 'april' => 4,
    'may' => 5,
    'jun' => 6, 'june' => 6,
    'jul' => 7, 'july' => 7,
    'aug' => 8, 'august' => 8,
    'sep' => 9, 'september' => 9,
    'oct' => 10, 'october' => 10,
    'nov' => 11, 'november' => 11,
    'dec' => 12, 'december' => 12
);

our %dow_map = (
    'sun' => 1, 'sunday' => 1,
    'mon' => 2, 'monday' => 2,
    'tue' => 3, 'tuesday' => 3,
    'wed' => 4, 'wednesday' => 4,
    'thu' => 5, 'thursday' => 5,
    'fri' => 6, 'friday' => 6,
    'sat' => 7, 'saturday' => 7
);

# Constants: Reverse maps (number -> name) for English descriptions
our @month_names = (undef, 'January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December');

our @day_names = (undef, 'Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
                  'Friday', 'Saturday');

our %nth_names = (
    1 => 'first',  2 => 'second', 3 => 'third', 4 => 'fourth', 5 => 'fifth'
);

# NEW: Frequency words
our %frequency_words = (
    1 => 'every',
    2 => 'every other',
    '*' => 'every'
);

# Special time phrases
our %time_specials = (
    hour   => { 0 => 'midnight', 12 => 'noon' },
    minute => { 0 => 'top of the', 30 => 'half past' }
);

# Unit labels for pluralization (singular, plural)
our %unit_labels = (
    second => ['second', 'seconds'],
    minute => ['minute', 'minutes'],
    hour   => ['hour', 'hours'],
    dom    => ['day', 'days'],
    month  => ['month', 'months'],
    dow    => ['day of the week', 'days of the week'],
    year   => ['year', 'years']
);

# Ordinals for DOM
our %ordinal_suffix = (1 => 'st', 2 => 'nd', 3 => 'rd', map { $_ => 'th' } 4..31);
our %day_ordinal = (map { $_ => $nth_names{$_} || "$_".($ordinal_suffix{$_}||'') } 1..31);

# Grammar helpers
our %prepositions = (second => 'at', minute => 'at', hour => 'at', dom => 'on the', month => 'in', dow => 'on', year => 'in');
our %joiners = (list => 'and', range => 'through');

# English helpers
sub format_time {
    my ($hour, $min) = @_;
    return '' unless defined $hour && defined $min;
    $hour = $hour % 12 || 12;
    return sprintf('%d:%02d %s', $hour, $min, $hour < 12 ? 'AM' : 'PM');
}

sub num_to_ordinal { 
    my $num = shift // return '';
    return $day_ordinal{$num} // "$num${ordinal_suffix{$num}//''}";
}

sub field_unit {
    my ($field, $count) = @_;
    $count //= 1;
    return '' unless exists $unit_labels{$field};
    my ($sing, $plur) = @{$unit_labels{$field}};
    return $count == 1 ? $sing : $plur;
}

sub join_parts {
    my @parts = grep { defined $_ && length $_ } @_;
    return '' if @parts == 0;
    return $parts[0] if @parts == 1;
    return join " $joiners{range} ", @parts if @parts == 2;
    return join(", ", @parts[0..$#parts-1]) . " $joiners{list} $parts[-1]";
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Utils - Shared constants and helpers for Cron::Describe

=cut
