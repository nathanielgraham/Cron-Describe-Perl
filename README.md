# Cron::Describe

A Perl module for parsing, validating, and generating human-readable descriptions of standard and Quartz cron expressions.

## Overview

`Cron::Describe` is a Perl library that processes cron expressions, validates their syntax, and generates clear, human-readable descriptions. It supports both **standard cron** (5 fields: minute, hour, day-of-month, month, day-of-week) and **Quartz Scheduler cron** (6 or 7 fields, including seconds and optional year, with special tokens like `L`, `W`, `#`, `?`). The module provides methods to:
- Parse cron expressions into structured data.
- Validate syntax and semantic correctness (e.g., day-of-month/month compatibility, Quartz DOM-DOW conflicts).
- Generate English descriptions (e.g., `* * * * *` → "Runs at 00:00 on every day-of-month, every month, every day-of-week").
- Check if a given timestamp matches the expression.

The module is designed for reliability, with robust error handling for invalid inputs (e.g., `60 * * * *`, `ABC * * * *`, incorrect field counts) and efficient validation for use in scheduling applications.

## Features
- **Standard and Quartz Support**: Handles both standard cron (5 fields) and Quartz cron (6 or 7 fields, with tokens like `L`, `W`, `#`, `?`).
- **Syntax Validation**: Checks for valid field formats, ranges, and special tokens.
- **Semantic Validation**: Ensures day-of-month/month compatibility, Quartz DOM-DOW rules, and year constraints (1970–2199).
- **Human-Readable Descriptions**: Converts cron expressions into clear English (e.g., `*/5 * * * *` → "Runs at every 5 minutes on every hour, every day-of-month, every month, every day-of-week").
- **Timestamp Matching**: Verifies if a given epoch timestamp matches the cron expression using `DateTime`.
- **Robust Error Handling**: Gracefully handles malformed inputs (e.g., non-numeric fields, incorrect field counts).
- **Extensible**: Ready for future features like `next()`/`previous()` for computing upcoming timestamps.

## Installation

### Prerequisites
- Perl 5.10 or higher
- Required modules:
  - `DateTime`
  - `DateTime::TimeZone`
  - `Test::More` (for testing)

### Using cpanm
```bash
cpanm .
```

### Manual Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/cron-describe.git
   cd cron-describe
   ```
2. Install dependencies:
   ```bash
   cpanm DateTime DateTime::TimeZone Test::More
   ```
3. Build and install:
   ```bash
   perl Makefile.PL
   make
   make install
   ```

### Using Dist::Zilla
If you’re contributing or testing:
```bash
dzil build
dzil install
dzil test --verbose
```

## Usage

### Basic Example
```perl
use Cron::Describe::Standard;

my $cron = Cron::Describe::Standard->new(expression => '* * * * *');
print $cron->to_english; # Output: Runs at 00:00 on every day-of-month, every month, every day-of-week
print $cron->is_valid ? "Valid\n" : "Invalid\n"; # Output: Valid
```

### Quartz Example
```perl
use Cron::Describe::Quartz;

my $cron = Cron::Describe::Quartz->new(expression => '*/5 * * * * ?');
print $cron->to_english; # Output: Runs at every 5 seconds:00:00 on every day-of-month, every month, every day-of-week
print $cron->is_valid ? "Valid\n" : "Invalid\n"; # Output: Valid
```

### Timestamp Matching
```perl
use Cron::Describe::Standard;
use Time::Local;

my $cron = Cron::Describe::Standard->new(expression => '0 0 1 * *');
my $epoch = timelocal(0, 0, 0, 1, 0, 125); # 2025-01-01 00:00:00
print $cron->is_match($epoch) ? "Matches\n" : "Does not match\n"; # Output: Matches
```

### Error Handling
```perl
use Cron::Describe::Standard;

my $cron = Cron::Describe::Standard->new(expression => 'ABC * * * *');
print $cron->is_valid ? "Valid\n" : "Invalid\n"; # Output: Invalid
print join(", ", @{$cron->{errors}}); # Output: Invalid format: ABC for minute
```

## Testing
The project includes a comprehensive test suite to ensure reliability:
- `t/validate.t`: Tests standard cron expressions (19 subtests).
- `t/validate_quartz.t`: Tests Quartz cron expressions (22 subtests).

Run tests with:
```bash
dzil test --verbose
```

Expected output:
```
All tests successful.
Files=2, Tests=41, ...
Result: PASS
```

The test suite covers:
- Valid expressions (e.g., `* * * * *`, `*/5 * * * * ?`).
- Invalid inputs (e.g., `60 * * * *`, `ABC * * * *`, `0 0 * * * * *`).
- Semantic validation (e.g., `31 2 * *` for February).
- Quartz-specific tokens (e.g., `L`, `W`, `#`, `?`).

## Project Structure
```
cron-describe/
├── lib/
│   ├── Cron/
│   │   ├── Describe.pm
│   │   ├── Describe/
│   │   │   ├── Field.pm
│   │   │   ├── DayOfMonth.pm
│   │   │   ├── DayOfWeek.pm
│   │   │   ├── Standard.pm
│   │   │   ├── Quartz.pm
├── t/
│   ├── validate.t
│   ├── validate_quartz.t
├── dist.ini
├── README.md
```

## Contributing
Contributions are welcome! To contribute:
1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/your-feature`).
3. Commit changes (`git commit -am 'Add your feature'`).
4. Run tests (`dzil test --verbose`).
5. Push to the branch (`git push origin feature/your-feature`).
6. Open a pull request.

Please include tests for new features and ensure all 41 subtests pass.

## Roadmap
- Implement `next()` and `previous()` methods for computing upcoming/previous timestamps.
- Enhance `to_english` with detailed error descriptions (e.g., “invalid minute ABC”).
- Add support for more edge cases (e.g., empty fields, partial expressions).
- Optimize for production by pruning debug attributes in error patterns.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact
This module was written by Grok4 with guidance from [ngraham@cpan.org](mailto:ngraham@cpan.org). 
