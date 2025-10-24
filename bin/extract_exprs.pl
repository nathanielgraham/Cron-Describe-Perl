#!/usr/bin/env perl
use strict;
use warnings;
use JSON::MaybeXS;  # For output

my %unique_exprs;
for my $file (glob('t/*.t')) {
    open my $fh, '<', $file or warn "Skip $file: $!\n" and next;
    my $content = do { local $/; <$fh> };
    # Main: expression => '...' or "..."
    while ($content =~ /expression\s*=>\s*(['"])(.*?)(?=\1)/gs) {
        my $expr = $2;
        $expr =~ s/\\(.)/$1/g;  # Unescape
        $unique_exprs{$expr} = 1;
    }
    # Bonus: q{...} or qq{...} blocks (common in tests)
    while ($content =~ /q[qr]?\{(.*?)\}/gs) {
        my $expr = $1;
        $expr =~ s/\\(.)/$1/g;
        $unique_exprs{$expr} = 1;
    }
}

my @exprs = sort keys %unique_exprs;

#say "# Extracted " . scalar(@exprs) . " unique expressions:\n";
print "'$_',\n" for @exprs;

#say encode_json(\@exprs);  # JSON array for generator.pl
