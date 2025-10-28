use strict;
use warnings;
use Test::More;

use Cron::Toolkit;

# Helper to display raw fields, normalized fields, and test post-optimization AST
sub test_ast {
   my ($desc, $expression, %tests) = @_;
   my $cron;
   eval {
      $cron = Cron::Toolkit->new(expression => $expression);
   };
   if ($tests{error}) {
      like($@, $tests{error}, "$desc: error");
   } else {
      #diag "Raw fields: [" . join(', ', @{ $cron->{raw_fields} }) . "]";
      diag "Normalized fields: [" . join(', ', @{ $cron->{fields} }) . "]";
      diag "Optimized expression: " . $cron->as_string;
      my $dow_node = $cron->{root}{children}[5]; # Check post-optimization
      while (my ($key, $value) = each %tests) {
         next if $key eq 'error';
         if ($key eq 'children') {
            is(scalar(@{ $dow_node->{children} }), scalar(@$value), "$desc: children count");
            for my $i (0 .. $#{ $value }) {
               is($dow_node->{children}[$i]->{type}, $value->[$i]->{type}, "$desc: child $i type");
               if (exists $value->[$i]->{value}) {
                  is($dow_node->{children}[$i]->{value}, $value->[$i]->{value}, "$desc: child $i value");
               } elsif (exists $value->[$i]->{children}) {
                  is(scalar(@{ $dow_node->{children}[$i]->{children} }), scalar(@{ $value->[$i]->{children} }), "$desc: child $i children count");
                  for my $j (0 .. $#{ $value->[$i]->{children} }) {
                     is($dow_node->{children}[$i]->{children}[$j]->{type}, $value->[$i]->{children}[$j]->{type}, "$desc: child $i subchild $j type");
                     is($dow_node->{children}[$i]->{children}[$j]->{value}, $value->[$i]->{children}[$j]->{value}, "$desc: child $i subchild $j value");
                  }
               }
            }
         } else {
            is($dow_node->{$key}, $value, "$desc: $key");
         }
      }
   }
}

# Unix DOW tests
test_ast(
   'Unix DOW 0: single',
   '30 14 * * 0',
   type => 'single',
   value => 0
);
test_ast(
   'Unix DOW 7: single',
   '30 14 * * 7',
   type => 'single',
   value => 0 # Post-optimization: 7 mapped to 0
);
test_ast(
   'Unix DOW SUN: single',
   '30 14 * * SUN',
   type => 'single',
   value => 0 # Post-optimization: SUN (7) mapped to 0
);
test_ast(
   'Unix DOW 7/2: single',
   '* * * * 7/2',
   type => 'single',
   value => 0 # Post-optimization: 7/2 collapses to single(7) then 0
);
test_ast(
   'Unix DOW 1,3,5: list',
   '* * * * 1,3,5',
   type => 'list',
   children => [
      { type => 'single', value => 1 },
      { type => 'single', value => 3 },
      { type => 'single', value => 5 }
   ]
);
test_ast(
   'Unix DOW 1-3,5: list',
   '* * * * 1-3,5',
   type => 'list',
   children => [
      { type => 'range', children => [
         { type => 'single', value => 1 },
         { type => 'single', value => 3 }
      ] },
      { type => 'single', value => 5 }
   ]
);

# Quartz DOW tests
test_ast(
   'Quartz DOW 1: normalized to 0',
   '0 0 0 ? * 1 *',
   type => 'single',
   value => 0
);
test_ast(
   'Quartz DOW 1#2: unchanged',
   '0 0 0 ? * 1#2 *',
   type => 'nth',
   value => '1#2'
);

# Invalid inputs
test_ast(
   'Quartz rejects DOW 0',
   '0 0 0 ? * 0 *',
   error => qr/Invalid dow value: 0, must be \[1-7\] in Quartz/
);
test_ast(
   'Rejects L in minute',
   'L * * * *',
   error => qr/Invalid characters in minute: L/
);
test_ast(
   'Rejects ? in year',
   '0 0 0 * * ? ?',
   error => qr/Invalid characters in year: \?/
);
test_ast(
   'Rejects invalid DOW range',
   '* * * * 5-1',
   error => qr/dow range start 5 must be <= end 1/
);
test_ast(
   'Rejects invalid list element',
   '* * * * 1,99',
   error => qr/dow 99 out of range \[0-7\]/
);

done_testing;
