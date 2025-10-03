#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib', 't/lib';
use Test::More;
use Test::CronPatterns;

# Run tests with invalid Quartz test
Test::CronPatterns::run_tests('quartz_tokens', test_invalid => 1);

done_testing();
