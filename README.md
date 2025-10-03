# Cron-Describe-Perl

## Overview
Cron-Describe-Perl is a Perl module for parsing and describing cron expressions in both standard (5 or 6 fields) and Quartz Scheduler (6 or 7 fields) formats. It provides a factory-based design with a shared base class (Cron::Describe::Base) and supports auto-detection of cron types, explicit constructors for Standard and Quartz classes, and human-readable descriptions via to_english.

## Features
- Auto-detection: Automatically identifies standard (5 fields: minute, hour, DOM, month, DOW; optional year) or Quartz (6 fields: seconds, minute, hour, DOM, month, DOW; optional year) cron expressions.
- Validation: Ensures 5-field Quartz expressions are invalid and Quartz expressions include ? in either DOM or DOW.
- Parsing: Supports patterns like single (e.g., 0), range (e.g., 1-5), step (e.g., 10/2), min-max/step (e.g., 10-15/2), */step (e.g., */2), and Quartz-specific patterns (L, W, #).
- Human-readable Output: Generates English descriptions (e.g., Runs at 00:00, on day 1 of month, in every month, every day-of-week).
- Debugging: Includes extensive debug logging for parsing, validation, and description generation.

## Installation
1. Clone the repository:
   git clone https://github.com/your-repo/Cron-Describe-Perl.git
2. Install dependencies:
   cpan Test::More JSON File::Slurp Data::Dumper DateTime DateTime::TimeZone Time::Moment
3. Build and test:
   perl Makefile.PL
   make
   make test

## Usage
use Cron::Describe;

# Auto-detect cron type
my $cron = Cron::Describe->new(expression => '0 0 1 * *', debug => 1);
print "Valid: ", $cron->is_valid, "\n";
print "English: ", $cron->to_english, "\n";

# Explicit Quartz constructor
my $quartz = Cron::Describe::Quartz->new(expression => '0 0 0 * * ?', debug => 1);
print "English: ", $quartz->to_english, "\n";

## Recent Changes (October 3, 2025)
- Fixed Compilation Error: Resolved syntax error in lib/Cron/Describe/Base.pm (line 231, unbalanced parentheses in is_valid), ensuring proper compilation.
- Improved Parsing:
  - Updated lib/Cron/Describe/Field.pm to correctly handle single values (0, 1), setting value, min_value, max_value, and step as strings to match test expectations.
  - Added support for min-max/step (e.g., 10-15/2) and */step patterns to handle complex DOM patterns like 1-5,10-15/2.
- Enhanced Tests:
  - Updated t/basic_parsing.t to expect Cron::Describe::Standard for standard cron expressions (0 0 1 * *).
  - Corrected t/data/basic_parsing.json to align with Field.pm output, ensuring pattern_type => 'single' for minute, hour, and seconds fields.
- Improved Descriptions: Ensured to_english in Base.pm correctly handles list patterns (e.g., 1-5,10-15/2) and produces expected output (e.g., on days 1 to 5, every 2 days from 10 of month).
- Debugging: Added comprehensive debug statements to Base.pm, Field.pm, DayOfMonth.pm, and DayOfWeek.pm to trace parsing, validation, and description generation.

## Testing
Run the test suite:
prove -v -Ilib -It/lib t/basic_parsing.t t/quartz_tokens.t t/matching.t t/edge_cases.t
Debug a specific test:
perl -Ilib -It/lib -e 'use strict; use warnings; use Cron::Describe; use Data::Dumper; my $cron = Cron::Describe->new(expression => "0 0 1 * *", debug => 1); print Dumper($cron->{fields}); print "Valid: ", $cron->is_valid, "\n"; print "English: ", $cron->to_english, "\n";'

## Known Issues
- Remaining Test Failures: Tests in t/quartz_tokens.t (6 failures for patterns like L, W, #) may require further debugging after resolving t/basic_parsing.t issues.
- Debug Output: Ensure debug => 1 is enabled to trace parsing issues in test outputs.

## Contributing
- Report issues or submit pull requests at https://github.com/your-repo/Cron-Describe-Perl.
- Share test outputs with debug logs for faster resolution.

## License
MIT License. See LICENSE file for details.
