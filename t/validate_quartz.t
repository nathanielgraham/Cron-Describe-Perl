#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib';    # Ensure lib/ is in @INC
use Test::More;
use Time::Moment;
use_ok('Cron::Describe::Quartz');

# Test cases: [expression, expected_fields, is_valid, test_name, optional {epoch, matches, desc}]
my @tests = (
   [
      '0 0 0 * * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0, max       => 7 }
      ],
      1,
      'Every day at midnight'
   ],
   [
      '0 0 0 L * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last',        offset => 0, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',    min    => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min    => 0, max       => 7 }
      ],
      1,
      'Last day of month'
   ],
   [
      '0 0 0 15W * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',          value => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',          value => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',          value => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'nearest_weekday', day   => 15, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',        min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',     min   => 0,  max       => 7 }
      ],
      1,
      'Nearest weekday to 15th'
   ],
   [
      '0 0 0 * * 1#5',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'nth',      day   => 1, nth       => 5, min => 0, max => 7, is_special => 1 }
      ],
      1,
      '5th Monday'
   ],
   [
      '0 0 0 * * 1#6',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'error',    min   => 0, max       => 7 }
      ],
      0,
      '6th Monday impossible'
   ],
   [
      '0 60 0 * * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'error',       value => 60, min_value => 60, max_value => 60, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1,  max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      0,
      'Invalid minute'
   ],
   [
      '0 0 0 31 2 ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'single',      value => 31, min_value => 31, max_value => 31, step => 1, min => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'single',      value => 2,  min_value => 2,  max_value => 2,  step => 1, min => 1, max => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      0,
      '31st of February (valid parse, invalid semantics)'
   ],
   [
      '0 0 0 * * 1L',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'last_of_day', day   => 1, min       => 0, max => 7, is_special => 1 }
      ],
      1,
      'Last Monday of month'
   ],
   [
      '0 0 0 * * ? 2025',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1,    max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,    max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'single',      value => 2025, min_value => 2025, max_value => 2025, step => 1, min => 1970, max => 2199 }
      ],
      1,
      'Every day in 2025'
   ],
   [
      '0 0 0 1-5,10-15/2 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         {
            field_type   => 'dom',
            pattern_type => 'list',
            min          => 1,
            max          => 31,
            sub_patterns => [
               { field_type => 'dom', pattern_type => 'range', min_value => 1,  max_value => 5,  step => 1 },
               { field_type => 'dom', pattern_type => 'range', min_value => 10, max_value => 15, step => 2 }
            ]
         },
         { field_type => 'month', pattern_type => 'wildcard',    min => 1, max => 12 },
         { field_type => 'dow',   pattern_type => 'unspecified', min => 0, max => 7 }
      ],
      1,
      'Complex DOM pattern'
   ],
   [
      '0 0 0 LW * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',       value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',       value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',       value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last_weekday', offset => 0, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',     min    => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',  min    => 0, max       => 7 }
      ],
      1,
      'Last weekday of month'
   ],
   [
      '5/10 * * * * ?',
      [
         { field_type => 'seconds', pattern_type => 'step',        start_value => 5, min_value => 5, max_value => 59, step => 10, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'wildcard',    min         => 0, max       => 59 },
         { field_type => 'hour',    pattern_type => 'wildcard',    min         => 0, max       => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min         => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min         => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min         => 0, max       => 7 }
      ],
      1,
      'Every 10 seconds starting at 5'
   ],
   [
      '0 5/15 * * * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value       => 0, min_value => 0, max_value => 0,  step => 1,  min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'step',        start_value => 5, min_value => 5, max_value => 59, step => 15, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'wildcard',    min         => 0, max       => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min         => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min         => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min         => 0, max       => 7 }
      ],
      1,
      'Every 15 minutes starting at 5'
   ],
   [
      '0 0 0 * * 2#3',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'nth',      day   => 2, nth       => 3, min => 0, max => 7, is_special => 1 }
      ],
      1,
      'Third Tuesday'
   ],
   [
      '0 0 0 ? * MON,WED,FRI',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'unspecified', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         {
            field_type   => 'dow',
            pattern_type => 'list',
            min          => 0,
            max          => 7,
            sub_patterns => [
               { field_type => 'dow', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1 },
               { field_type => 'dow', pattern_type => 'single', value => 3, min_value => 3, max_value => 3, step => 1 },
               { field_type => 'dow', pattern_type => 'single', value => 5, min_value => 5, max_value => 5, step => 1 }
            ]
         }
      ],
      1,
      'DOW list with names'
   ],
   [
      '0 0 0 LW * MON',
      [
         { field_type => 'seconds', pattern_type => 'single',       value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',       value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',       value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last_weekday', offset => 0, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',     min    => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'single',       value  => 1, min_value => 1, max_value => 1, step => 1, min => 0, max => 7 }
      ],
      0,
      'LW with specific DOW'
   ],
   [
      '0 0 0 * * ?W',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'error',    min   => 0, max       => 7 }
      ],
      0,
      'Invalid Quartz token ?W'
   ],
   [
      '*/5 0 * * * ?',
      [
         { field_type => 'seconds', pattern_type => 'step',        start_value => 0, min_value => 0, max_value => 59, step => 5, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value       => 0, min_value => 0, max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'wildcard',    min         => 0, max       => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min         => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min         => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min         => 0, max       => 7 }
      ],
      1,
      'Every second in first minute'
   ],
   [
      '0 0 0 L-5 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last',        offset => 5, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',    min    => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min    => 0, max       => 7 }
      ],
      1,
      'Last day minus offset'
   ],
   [
      '0 0 0 32W * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'error',       min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0, max       => 7 }
      ],
      0,
      'Invalid nearest weekday'
   ],
   [
      '0 0 0 * * 8#3',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'error',    min   => 0, max       => 7 }
      ],
      0,
      'Invalid nth day'
   ],
   [
      '0 0 0 * * W#3',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'error',    min   => 0, max       => 7 }
      ],
      0,
      'Malformed Quartz token'
   ],
   [
      '0 0 0 15 * MON',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'single',   value => 15, min_value => 15, max_value => 15, step => 1, min => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'single',   value => 1,  min_value => 1, max_value => 1, step => 1, min => 0, max => 7 }
      ],
      0,
      'Quartz DOM-DOW conflict'
   ],
   [
      '0 0 0 ? * 1#5',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'unspecified', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'nth',         day   => 1, nth       => 5, min => 0, max => 7, is_special => 1 }
      ],
      1,
      'Valid nth day'
   ],
   [
      '0 0 0 * * ? 1969',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1,    max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,    max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'error',       value => 1969, min_value => 1969, max_value => 1969, step => 1, min => 1970, max => 2199 }
      ],
      0,
      'Invalid past year'
   ],
   [
      '0 0 0 * * ? 2025-2030',
      [
         { field_type => 'seconds', pattern_type => 'single',      value     => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value     => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value     => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min       => 1,    max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min       => 1,    max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min       => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'range',       min_value => 2025, max_value => 2030, step => 1, min => 1970, max => 2199 }
      ],
      1,
      'Valid year range'
   ],
   [
      '0 0 0 31 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'single',      value => 31, min_value => 31, max_value => 31, step => 1, min => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      1,
      'DOM 31 with wildcard month (valid for some months)'
   ],
   [
      '0 0 0 1,3,31 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         {
            field_type   => 'dom',
            pattern_type => 'list',
            min          => 1,
            max          => 31,
            sub_patterns => [
               { field_type => 'dom', pattern_type => 'single', value => 1,  min_value => 1,  max_value => 1,  step => 1 },
               { field_type => 'dom', pattern_type => 'single', value => 3,  min_value => 3,  max_value => 3,  step => 1 },
               { field_type => 'dom', pattern_type => 'single', value => 31, min_value => 31, max_value => 31, step => 1 }
            ]
         },
         { field_type => 'month', pattern_type => 'wildcard',    min => 1, max => 12 },
         { field_type => 'dow',   pattern_type => 'unspecified', min => 0, max => 7 }
      ],
      1,
      'DOM list with 31 and wildcard month (valid for some months)'
   ],
   [
      '0 0 0 32 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'error',       value => 32, min_value => 32, max_value => 32, step => 1, min => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      0,
      'DOM 32 with wildcard month (invalid for all months)'
   ],
   [
      '0 0 0 0/0 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'error',       min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0, max       => 7 }
      ],
      0,
      'Invalid step 0 in DOM'
   ],
   [
      '0 0 0 1-31 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value     => 0, min_value => 0,  max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value     => 0, min_value => 0,  max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value     => 0, min_value => 0,  max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'range',       min_value => 1, max_value => 31, step      => 1, min  => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min       => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min       => 0, max       => 7 }
      ],
      1,
      'DOM range 1-31 with wildcard month (valid for some months)'
   ],
   [
      '0 0 0 L-10 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value  => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value  => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value  => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last',        offset => 10, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',    min    => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min    => 0,  max       => 7 }
      ],
      1,
      'Last day minus 10 offset'
   ],
   [
      '0 0 0 1W * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'nearest_weekday', day   => 1, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',        min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',     min   => 0, max       => 7 }
      ],
      1,
      'Nearest weekday to 1st'
   ],
   [
      '0 0 0 * * 7#1',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'nth',      day   => 7, nth       => 1, min => 0, max => 7, is_special => 1 }
      ],
      1,
      'First Sunday'
   ],
   [
      '59 59 23 * * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 59, min_value => 59, max_value => 59, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 59, min_value => 59, max_value => 59, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 23, min_value => 23, max_value => 23, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1,  max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      1,
      'Boundary values for seconds, minutes, hours'
   ],
   [
      '0 0 0 29 2 ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'single',      value => 29, min_value => 29, max_value => 29, step => 1, min => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'single',      value => 2,  min_value => 2,  max_value => 2,  step => 1, min => 1, max => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      1,
      '29th of February (valid for leap years)'
   ],
   [
      '0 0 0 * * ? 2025/2',
      [
         { field_type => 'seconds', pattern_type => 'single',      value       => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value       => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value       => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min         => 1,    max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min         => 1,    max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min         => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'step',        start_value => 2025, min_value => 2025, max_value => 2199, step => 2, min => 1970, max => 2199 }
      ],
      1,
      'Every other year starting 2025'
   ],
   [
      '0 0 0 * * ? 2200',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1,    max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,    max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'error',       value => 2200, min_value => 2200, max_value => 2200, step => 1, min => 1970, max => 2199 }
      ],
      0,
      'Year beyond max (2200)'
   ],
   [
      '0 0 0 -1 * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0,  max_value => 0,  step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'error',       value => -1, min_value => -1, max_value => -1, step => 1, min => 1, max => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      0,
      'Negative DOM value'
   ],
   [
      '0 0 0 * 13 ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0,  min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0,  min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0,  min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1,  max       => 31 },
         { field_type => 'month',   pattern_type => 'error',       value => 13, min_value => 13, max_value => 13, step => 1, min => 1, max => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min   => 0,  max       => 7 }
      ],
      0,
      'Invalid month (13)'
   ],
   [ '', [], 0, 'Empty expression' ],
   [
      '0 0 0 L * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value  => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last',        offset => 0, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',    min    => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified', min    => 0, max       => 7 }
      ],
      1,
      'Last day of month (match test)',

      # Test matching for February 29, 2024 (leap year)
      {
         epoch   => Time::Moment->new( year => 2024, month => 2, day => 29, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on last day of month, every month'
      }
   ],
   [
      '0 0 0 15W * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',          value => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',          value => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',          value => 0,  min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'nearest_weekday', day   => 15, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',        min   => 1,  max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',     min   => 0,  max       => 7 }
      ],
      1,
      'Nearest weekday to 15th (match test)',

      # Test matching for October 15, 2025 (Wednesday, no adjustment needed)
      {
         epoch   => Time::Moment->new( year => 2025, month => 10, day => 15, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on nearest weekday to day 15, every month'
      }
   ],
   [
      '0 0 0 * * 1#3',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard', min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'nth',      day   => 1, nth       => 3, min => 0, max => 7, is_special => 1 }
      ],
      1,
      'Third Monday (match test)',

      # Test matching for third Monday in October 2025 (October 20, 2025)
      {
         epoch   => Time::Moment->new( year => 2025, month => 10, day => 20, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on third Monday, every month'
      }
   ],
   [
      '0 0 0 * * 1L',
      [
         { field_type => 'seconds', pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',      value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard',    min   => 1, max       => 31 },
         { field_type => 'month',   pattern_type => 'wildcard',    min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'last_of_day', day   => 1, min       => 0, max => 7, is_special => 1 }
      ],
      1,
      'Last Monday of month (match test)',

      # Test matching for last Monday in October 2025 (October 27, 2025)
      {
         epoch   => Time::Moment->new( year => 2025, month => 10, day => 27, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on last Monday of month, every month'
      }
   ],

   [
      '0 0 0 LW 2 ? 2024',
      [
         { field_type => 'seconds', pattern_type => 'single',       value  => 0,    min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',       value  => 0,    min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',       value  => 0,    min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last_weekday', offset => 0,    min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'single',       value  => 2,    min_value => 2, max_value => 2,  step       => 1, min => 1, max => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',  min    => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'single',       value  => 2024, min_value => 2024, max_value => 2024, step => 1, min => 1970, max => 2199 }
      ],
      1,
      'Last weekday of February 2024 (leap year)',
      {
         epoch   => Time::Moment->new( year => 2024, month => 2, day => 29, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on last weekday of month, February, 2024'
      }
   ],
   [
      '0 0 0 LW 2 ? 2025',
      [
         { field_type => 'seconds', pattern_type => 'single',       value  => 0,    min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',       value  => 0,    min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',       value  => 0,    min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'last_weekday', offset => 0,    min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'single',       value  => 2,    min_value => 2, max_value => 2,  step       => 1, min => 1, max => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',  min    => 0,    max       => 7 },
         { field_type => 'year',    pattern_type => 'single',       value  => 2025, min_value => 2025, max_value => 2025, step => 1, min => 1970, max => 2199 }
      ],
      1,
      'Last weekday of February 2025 (non-leap year)',
      {
         epoch   => Time::Moment->new( year => 2025, month => 2, day => 28, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on last weekday of month, February, 2025'
      }
   ],

   [
      '0 0 0 7W * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'nearest_weekday', day   => 7, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',        min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',     min   => 0, max       => 7 }
      ],
      1,
      'Nearest weekday to 7th (weekend test)',

      # October 7, 2025 is a Tuesday, so no adjustment needed
      {
         epoch   => Time::Moment->new( year => 2025, month => 10, day => 7, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on nearest weekday to day 7, every month'
      },

      # October 5, 2025 is a Sunday, so 7W should adjust to October 6 (Monday)
      {
         epoch   => Time::Moment->new( year => 2025, month => 10, day => 6, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on nearest weekday to day 7, every month'
      }
   ],
   [
      '0 0 0 8W * ?',
      [
         { field_type => 'seconds', pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',          value => 0, min_value => 0, max_value => 0,  step       => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'nearest_weekday', day   => 8, min       => 1, max       => 31, is_special => 1 },
         { field_type => 'month',   pattern_type => 'wildcard',        min   => 1, max       => 12 },
         { field_type => 'dow',     pattern_type => 'unspecified',     min   => 0, max       => 7 }
      ],
      1,
      'Nearest weekday to 8th (weekend test)',

      # October 8, 2023 is a Sunday, so 8W should adjust to October 9 (Monday)
      {
         epoch   => Time::Moment->new( year => 2023, month => 10, day => 9, hour => 0, minute => 0, second => 0 )->epoch,
         matches => 1,
         desc    => 'Runs at 00:00:00 on nearest weekday to day 8, every month'
      }
   ],
   [
      '0 0 0 * 2 1#5 2025',
      [
         { field_type => 'seconds', pattern_type => 'single',   value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'minute',  pattern_type => 'single',   value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
         { field_type => 'hour',    pattern_type => 'single',   value => 0,    min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
         { field_type => 'dom',     pattern_type => 'wildcard', min   => 1,    max       => 31 },
         { field_type => 'month',   pattern_type => 'single',   value => 2,    min_value => 2,    max_value => 2,    step => 1, min        => 1, max => 12 },
         { field_type => 'dow',     pattern_type => 'nth',      day   => 1,    nth       => 5,    min       => 0,    max  => 7, is_special => 1 },
         { field_type => 'year',    pattern_type => 'single',   value => 2025, min_value => 2025, max_value => 2025, step => 1, min        => 1970, max => 2199 }
      ],
      0,    # Invalid because February 2025 has only 4 Mondays
      '5th Monday in February 2025 (impossible)'
   ]
);

for my $test (@tests) {
    my ($expr, $expected_fields, $is_valid, $name, $extra) = @$test;
    subtest $name => sub {
        my $cron = eval { Cron::Describe::Quartz->new(expression => $expr, debug => 1) };
        if ($@ || !defined $cron) {
            ok(!$is_valid, "Expected parse failure ($@)");
            return;
        }
        my @fields = @{$cron->{fields} || []};
        is_deeply(
            [ map { {
                field_type => $_->{field_type},
                pattern_type => $_->{pattern_type},
                (exists $_->{value} ? (value => $_->{value}) : ()),
                (exists $_->{min_value} ? (min_value => $_->{min_value}) : ()),
                (exists $_->{max_value} ? (max_value => $_->{max_value}) : ()),
                (exists $_->{start_value} ? (start_value => $_->{start_value}) : ()),
                (exists $_->{step} ? (step => $_->{step}) : ()),
                (exists $_->{offset} ? (offset => $_->{offset}) : ()),
                (exists $_->{day} ? (day => $_->{day}) : ()),
                (exists $_->{nth} ? (nth => $_->{nth}) : ()),
                (exists $_->{is_special} ? (is_special => $_->{is_special}) : ()),
                min => $_->{min},
                max => $_->{max},
                (exists $_->{sub_patterns} ? (sub_patterns => [
                    map { {
                        field_type => $_->{field_type},
                        pattern_type => $_->{pattern_type},
                        (exists $_->{value} ? (value => $_->{value}) : ()),
                        (exists $_->{min_value} ? (min_value => $_->{min_value}) : ()),
                        (exists $_->{max_value} ? (max_value => $_->{max_value}) : ()),
                        (exists $_->{start_value} ? (start_value => $_->{start_value}) : ()),
                        (exists $_->{step} ? (step => $_->{step}) : ()),
                        (exists $_->{offset} ? (offset => $_->{offset}) : ()),
                        (exists $_->{day} ? (day => $_->{day}) : ()),
                        (exists $_->{nth} ? (nth => $_->{nth}) : ())
                    } } @{$_->{sub_patterns}}
                ]) : ())
            } } @fields ],
            $expected_fields,
            "Parsed fields match expected structure"
        );
        is($cron->is_valid, $is_valid, "is_valid");
        if ($extra && exists $extra->{epoch}) {
            my $match_result;
            eval {
                $match_result = $cron->is_match($extra->{epoch});
            };
            if ($@) {
                fail("Matches timestamp for $name: $@");
            } else {
                is($match_result, $extra->{matches}, "Matches timestamp for $name");
            }
            is($cron->to_english, $extra->{desc}, "English description for $name");
        }
    };
}

done_testing();

