use Time::Moment;
use JSON::MaybeXS;
use File::Slurp;

my $json = decode_json(read_file('t/data/quartz_tokens.json'));
for my $test (@$json) {
    next unless $test->{extras};
    for my $extra (@{$test->{extras}}) {
        my $tm = Time::Moment->from_epoch($extra->{epoch})->with_offset_same_instant($test->{utc_offset});
        my ($y, $m, $d, $h, $min, $s) = ($tm->year, $tm->month, $tm->day_of_month, $tm->hour, $tm->minute, $tm->second);
        print "Validating $test->{expression}: $y-$m-$d $h:$min:$s, epoch=$extra->{epoch}\n";
        if ($test->{expression} =~ /LW 2 \? 2024/ && ($h != 0 || $min != 0 || $s != 0)) {
            die "Invalid timestamp for LW 2 ? 2024: expected midnight, got $h:$min:$s";
        }
    }
}
