#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use_ok('Cron::Describe::Quartz');

# Test cases: [expression, expected_fields, is_valid, test_name]
my @tests = (
    [
        '0 0 0 * * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Every day at midnight'
    ],
    [
        '0 0 0 L * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'last', offset => 0, min => 1, max => 31, is_special => 1 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Last day of month'
    ],
    [
        '0 0 0 15W * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'nearest_weekday', day => 15, min => 1, max => 31, is_special => 1 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Nearest weekday to 15th'
    ],
    [
        '0 0 0 * * 1#5',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'nth', day => 1, nth => 5, min => 0, max => 7, is_special => 1 }
        ],
        1,
        '5th Monday'
    ],
    [
        '0 0 0 * * 1#6',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'error', min => 0, max => 7 }
        ],
        0,
        '6th Monday impossible'
    ],
    [
        '0 60 0 * * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'error', value => 60, min_value => 60, max_value => 60, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        0,
        'Invalid minute'
    ],
    [
        '0 0 0 31 2 ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'single', value => 31, min_value => 31, max_value => 31, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'single', value => 2, min_value => 2, max_value => 2, step => 1, min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        0,
        '31st of February (valid parse, invalid semantics)'
    ],
    [
        '0 0 0 * * 1L',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'last_of_day', day => 1, min => 0, max => 7, is_special => 1 }
        ],
        1,
        'Last Monday of month'
    ],
    [
        '0 0 0 * * ? 2025',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 },
            { field_type => 'year', pattern_type => 'single', value => 2025, min_value => 2025, max_value => 2025, step => 1, min => 1970, max => 2199 }
        ],
        1,
        'Every day in 2025'
    ],
    [
        '0 0 0 1-5,10-15/2 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            {
                field_type => 'dom',
                pattern_type => 'list',
                min => 1,
                max => 31,
                sub_patterns => [
                    { field_type => 'dom', pattern_type => 'range', min_value => 1, max_value => 5, step => 1 },
                    { field_type => 'dom', pattern_type => 'range', min_value => 10, max_value => 15, step => 2 }
                ]
            },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Complex DOM pattern'
    ],
    [
        '0 0 0 LW * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'last_weekday', offset => 0, min => 1, max => 31, is_special => 1 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Last weekday of month'
    ],
    [
        '5/10 * * * * ?',
        [
            { field_type => 'seconds', pattern_type => 'step', start_value => 5, min_value => 5, max_value => 59, step => 10, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'wildcard', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Every 10 seconds starting at 5'
    ],
    [
        '0 5/15 * * * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'step', start_value => 5, min_value => 5, max_value => 59, step => 15, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Every 15 minutes starting at 5'
    ],
    [
        '0 0 0 * * 2#3',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'nth', day => 2, nth => 3, min => 0, max => 7, is_special => 1 }
        ],
        1,
        'Third Tuesday'
    ],
    [
        '0 0 0 ? * MON,WED,FRI',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'unspecified', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            {
                field_type => 'dow',
                pattern_type => 'list',
                min => 0,
                max => 7,
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
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'last_weekday', offset => 0, min => 1, max => 31, is_special => 1 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1, min => 0, max => 7 }
        ],
        0,
        'LW with specific DOW'
    ],
    [
        '0 0 0 * * ?W',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'error', min => 0, max => 7 }
        ],
        0,
        'Invalid Quartz token ?W'
    ],
    [
        '*/5 0 * * * ?',
        [
            { field_type => 'seconds', pattern_type => 'step', start_value => 0, min_value => 0, max_value => 59, step => 5, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Every second in first minute'
    ],
    [
        '0 0 0 L-5 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'last', offset => 5, min => 1, max => 31, is_special => 1 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'Last day minus offset'
    ],
    [
        '0 0 0 32W * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'error', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        0,
        'Invalid nearest weekday'
    ],
    [
        '0 0 0 * * 8#3',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'error', min => 0, max => 7 }
        ],
        0,
        'Invalid nth day'
    ],
    [
        '0 0 0 * * W#3',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'error', min => 0, max => 7 }
        ],
        0,
        'Malformed Quartz token'
    ],
    [
        '0 0 0 15 * MON',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'single', value => 15, min_value => 15, max_value => 15, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1, min => 0, max => 7 }
        ],
        0,
        'Quartz DOM-DOW conflict'
    ],
    [
        '0 0 0 ? * 1#5',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'unspecified', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'nth', day => 1, nth => 5, min => 0, max => 7, is_special => 1 }
        ],
        1,
        'Valid nth day'
    ],
    [
        '0 0 0 * * ? 1969',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 },
            { field_type => 'year', pattern_type => 'error', value => 1969, min_value => 1969, max_value => 1969, step => 1, min => 1970, max => 2199 }
        ],
        0,
        'Invalid past year'
    ],
    [
        '0 0 0 * * ? 2025-2030',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 },
            { field_type => 'year', pattern_type => 'range', min_value => 2025, max_value => 2030, step => 1, min => 1970, max => 2199 }
        ],
        1,
        'Valid year range'
    ],
    [
        '0 0 0 31 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'single', value => 31, min_value => 31, max_value => 31, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'DOM 31 with wildcard month (valid for some months)'
    ],
    [
        '0 0 0 1,3,31 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            {
                field_type => 'dom',
                pattern_type => 'list',
                min => 1,
                max => 31,
                sub_patterns => [
                    { field_type => 'dom', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1 },
                    { field_type => 'dom', pattern_type => 'single', value => 3, min_value => 3, max_value => 3, step => 1 },
                    { field_type => 'dom', pattern_type => 'single', value => 31, min_value => 31, max_value => 31, step => 1 }
                ]
            },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'DOM list with 31 and wildcard month (valid for some months)'
    ],
    [
        '0 0 0 32 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'error', value => 32, min_value => 32, max_value => 32, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        0,
        'DOM 32 with wildcard month (invalid for all months)'
    ],
    [
        '0 0 0 0/0 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'error', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        0,
        'Invalid step 0 in DOM'
    ],
    [
        '0 0 0 1-31 * ?',
        [
            { field_type => 'seconds', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'range', min_value => 1, max_value => 31, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'unspecified', min => 0, max => 7 }
        ],
        1,
        'DOM range 1-31 with wildcard month (valid for some months)'
    ],
);

for my $test (@tests) {
    my ($expr, $expected_fields, $is_valid, $name) = @$test;
    subtest $name => sub {
        my $cron = eval { Cron::Describe::Quartz->new(expression => $expr) };
        if ($@) {
            ok(0, "Failed to parse ($@)");
            return;
        }
        my @fields = @{$cron->{fields}};
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
    };
}
done_testing();
