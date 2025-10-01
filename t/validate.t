#!/usr/bin/perl
use strict;
use warnings;
use Test::More;
use_ok('Cron::Describe::Standard');

# Test cases: [expression, expected_fields, is_valid, test_name]
my @tests = (
    [
        '* * * * *',
        [
            { field_type => 'minute', pattern_type => 'wildcard', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Every minute'
    ],
    [
        '0 0 1 * *',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Midnight on 1st'
    ],
    [
        '1-5,10-15/2 * * * *',
        [
            {
                field_type => 'minute',
                pattern_type => 'list',
                min => 0,
                max => 59,
                sub_patterns => [
                    { field_type => 'minute', pattern_type => 'range', min_value => 1, max_value => 5, step => 1 },
                    { field_type => 'minute', pattern_type => 'range', min_value => 10, max_value => 15, step => 2 }
                ]
            },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Complex minute pattern'
    ],
    [
        '60 * * * *',
        [
            { field_type => 'minute', pattern_type => 'error', value => 60, min_value => 60, max_value => 60, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        0,
        'Invalid minute'
    ],
    [
        '* * 31 2 *',
        [
            { field_type => 'minute', pattern_type => 'wildcard', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'single', value => 31, min_value => 31, max_value => 31, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'single', value => 2, min_value => 2, max_value => 2, step => 1, min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        0,
        '31st of February'
    ],
    [
        '0 0 * * SUN',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 7 }
        ],
        1,
        'Every Sunday midnight'
    ],
    [
        '*/15 * * * *',
        [
            { field_type => 'minute', pattern_type => 'step', start_value => 0, min_value => 0, max_value => 59, step => 15, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Every 15 minutes'
    ],
    [
        '1,3,5 * * JAN,FEB *',
        [
            {
                field_type => 'minute',
                pattern_type => 'list',
                min => 0,
                max => 59,
                sub_patterns => [
                    { field_type => 'minute', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1 },
                    { field_type => 'minute', pattern_type => 'single', value => 3, min_value => 3, max_value => 3, step => 1 },
                    { field_type => 'minute', pattern_type => 'single', value => 5, min_value => 5, max_value => 5, step => 1 }
                ]
            },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            {
                field_type => 'month',
                pattern_type => 'list',
                min => 1,
                max => 12,
                sub_patterns => [
                    { field_type => 'month', pattern_type => 'single', value => 1, min_value => 1, max_value => 1, step => 1 },
                    { field_type => 'month', pattern_type => 'single', value => 2, min_value => 2, max_value => 2, step => 1 }
                ]
            },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Specific minutes in Jan/Feb'
    ],
    [
        '0 * * * *',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Every hour on the hour'
    ],
    [
        '0 0 * * 1-5',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'range', min_value => 1, max_value => 5, step => 1, min => 0, max => 7 }
        ],
        1,
        'Weekdays midnight'
    ],
    [
        '0 -1 * * *',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'error', value => -1, min_value => -1, max_value => -1, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        0,
        'Negative value in hour'
    ],
    [
        '0 0 1-10/3 * *',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'range', min_value => 1, max_value => 10, step => 3, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'Step with range in DOM'
    ],
    [
        '* * 31 * *',
        [
            { field_type => 'minute', pattern_type => 'wildcard', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'single', value => 31, min_value => 31, max_value => 31, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'DOM 31 with wildcard month (valid for some months)'
    ],
    [
        '* * 1,3,31 * *',
        [
            { field_type => 'minute', pattern_type => 'wildcard', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
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
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'DOM list with 31 and wildcard month (valid for some months)'
    ],
    [
        '* * 32 * *',
        [
            { field_type => 'minute', pattern_type => 'wildcard', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'error', value => 32, min_value => 32, max_value => 32, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        0,
        'DOM 32 with wildcard month (invalid for all months)'
    ],
    [
        '0 0 0/0 * *',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'error', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        0,
        'Invalid step 0 in DOM'
    ],
    [
        '0 0 1-31 * *',
        [
            { field_type => 'minute', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'single', value => 0, min_value => 0, max_value => 0, step => 1, min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'range', min_value => 1, max_value => 31, step => 1, min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        1,
        'DOM range 1-31 with wildcard month (valid for some months)'
    ],
    [
        'ABC * * * *',
        [
            { field_type => 'minute', pattern_type => 'error', min => 0, max => 59 },
            { field_type => 'hour', pattern_type => 'wildcard', min => 0, max => 23 },
            { field_type => 'dom', pattern_type => 'wildcard', min => 1, max => 31 },
            { field_type => 'month', pattern_type => 'wildcard', min => 1, max => 12 },
            { field_type => 'dow', pattern_type => 'wildcard', min => 0, max => 7 }
        ],
        0,
        'Non-numeric minute'
    ],
    [
        '0 0 * * * * *',
        [],
        0,
        'Too many fields'
    ],
);

for my $test (@tests) {
    my ($expr, $expected_fields, $is_valid, $name) = @$test;
    subtest $name => sub {
        my $cron = eval { Cron::Describe::Standard->new(expression => $expr) };
        if ($@) {
            ok(0, "Failed to parse ($@)");
            return;
        }
        my @fields = @{$cron->{fields} // []};
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
