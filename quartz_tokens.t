#!/usr/bin/perl
use strict;
use warnings;
use lib 'lib', 't/lib';
use Test::More;
use Test::QuartzPatterns;

Test::QuartzPatterns::run_tests('quartz_tokens');
done_testing();
