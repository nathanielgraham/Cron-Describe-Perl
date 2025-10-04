'README.md' => <<'END_README',
# Cron-Describe-Perl
Cron-Describe-Perl is a Perl library for parsing, validating, and describing cron expressions in both standard and Quartz Scheduler formats. This project provides a robust class hierarchy to accurately represent cron expressions, validate their correctness, and check if specific timestamps match the expression. The current implementation focuses on reliable parsing, validation, and matching, with plans to enhance human-readable descriptions (`to_english`) in the future.

## Project Overview
The library processes cron expressions such as `0 0 0 * * ?`, `0 0 0 1-5,10-15/2 * ?`, and `0 0 1 * *`, supporting:

- **Standard cron format**: 5 fields (minute, hour, day of month, month, day of week) or 6 fields with an optional year.
- **Quartz Scheduler format**: 6 fields (seconds, minute, hour, day of month, month, day of week) or 7 fields with an optional year, supporting `?` for unspecified fields and special patterns like `L`, `LW`, `#`, and `W`.

The implementation uses an object-oriented class hierarchy to represent different cron field patterns, ensuring flexibility and extensibility.

## Class Hierarchy
The library is built around the following classes, located in `lib/Cron/Describe/`:

- **CronExpression**: The main class for parsing and validating a full cron expression. It stores the expression, determines its type (standard or Quartz), and holds a hash of field patterns.
- **Pattern**: An abstract base class for field patterns, defining common methods (`validate`, `is_match`, `to_english`, `to_string`).
- **WildcardPattern**: Represents `*` (matches all values in the field's range).
- **UnspecifiedPattern**: Represents `?` (Quartz-specific, matches any value).
- **SinglePattern**: Represents a single value (e.g., `0`, `15`).
- **RangePattern**: Represents a range (e.g., `1-5`).
- **StepPattern**: Represents a step pattern (e.g., `10-15/2` for every other value from 10 to 15).
- **ListPattern**: Represents a comma-separated list (e.g., `1-5,10-15/2`).
- **DayOfMonthPattern**: Handles day-of-month patterns, including special Quartz patterns (`L`, `LW`, `\d+W`, `L-\d+`).
- **DayOfWeekPattern**: Handles day-of-week patterns, including special Quartz patterns (`\d+#\d+`, `\d+L`).

## Features
- **Parsing**: Accurately parses cron expressions into a structured object model, auto-detecting standard or Quartz format based on field count and presence of `?`.
- **Validation**: The `validate` method checks if the expression is valid, ensuring correct field counts, value ranges, and Quartz-specific rules (e.g., either `dom` or `dow` must be `?` if both are specified).
- **Matching**: The `is_match` method determines if a given epoch timestamp matches the cron expression.
- **String Representation**: The `to_string` method reconstructs the original cron expression.
- **English Description**: The `to_english` method provides a basic human-readable description (e.g., "Runs at 00:00:00, every day of month, in every month, any day-of-week"). Idiomatic descriptions will be enhanced in future updates.

## Installation
1. Clone the repository or unzip the project files:
    git clone https://github.com/nathanielgraham/cron-describe-perl.git
    cd cron-describe-perl
   Or, unzip the downloaded zip file (e.g., from a GitHub Gist).

2. Install required Perl modules:
    cpan Time::Moment DateTime Test::More

## Project Structure
    Cron-Describe-Perl/
    ├── lib/
    │   └── Cron/
    │       └── Describe/
    │           ├── CronExpression.pm
    │           ├── Pattern.pm
    │           ├── WildcardPattern.pm
    │           ├── UnspecifiedPattern.pm
    │           ├── SinglePattern.pm
    │           ├── RangePattern.pm
    │           ├── StepPattern.pm
    │           ├── ListPattern.pm
    │           ├── DayOfMonthPattern.pm
    │           └── DayOfWeekPattern.pm
    ├── t/
    │   ├── compile.t
    │   └── cron_expression.t
    └── README.md

- `lib/Cron/Describe/`: Contains the class hierarchy for parsing and handling cron expressions.
- `t/compile.t`: Tests that all modules compile successfully.
- `t/cron_expression.t`: Tests parsing, validation, and matching for key cron expressions.

## Testing
Run the test suite to verify the implementation:

1. **Compilation Test**:
    prove -v -Ilib t/compile.t
   Ensures all modules load without syntax errors.

2. **Parsing and Validation Test**:
    prove -v -Ilib t/cron_expression.t
   Tests parsing, validation, and matching for expressions like:
   - `0 0 0 * * ?` (Quartz, every day at midnight)
   - `0 0 0 1-5,10-15/2 * ?` (Quartz, days 1-5 and every other day from 10-15)
   - `0 0 1 * *` (Standard, first day of every month at midnight)
   - `0 0 0 L * ?` (Quartz, last day of month)
   - Invalid cases like `0 0 0 * *` (wrong field count) and `0 0 0 32 * ?` (out-of-range day)

## Current Focus
The current implementation prioritizes:
1. **Parser Correctness**: Accurately parsing cron expressions into the correct `Pattern` subclasses with proper attributes (e.g., `value` for `SinglePattern`, `min` and `max` for `RangePattern`).
2. **Validation**: Ensuring the `validate` method correctly identifies valid and invalid expressions, including field count checks and Quartz-specific rules.
3. **Matching**: Verifying that `is_match` correctly determines if a timestamp matches the expression.

Future work will enhance the `to_english` method for more idiomatic human-readable descriptions.

## Contributing
Contributions are welcome! Please submit issues or pull requests to the [GitHub repository](https://github.com/nathanielgraham/cron-describe-perl). Focus areas include improving `to_english` output and adding more test cases for complex Quartz patterns.

## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
END_README
