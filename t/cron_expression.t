#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Deep;
use JSON::MaybeXS;
use File::Slurp;
use Try::Tiny;
use Time::Moment;
use lib 'lib';
use Cron::Describe;

# Load test data
my @json_files = qw(t/data/all_tests.json);
my @all_tests;
foreach my $file (@json_files) {
   try {
      my $data = decode_json( read_file($file) );
      push @all_tests, @$data;
   }
   catch {
      diag "Failed to load $file: $_";
      fail "Loading JSON file $file";
   };
}

# Validate test data
foreach my $test (@all_tests) {
   unless ( exists $test->{expression} && defined $test->{expression} ) {
      diag "Test data missing or undefined 'expression' field: skipping test";
      $test->{is_valid} = 0;    # Default to invalid
      next;
   }
   if ( !exists $test->{is_valid} || !defined $test->{is_valid} ) {
      diag "Test data missing or undefined 'is_valid' field for expression: $test->{expression}";
      $test->{is_valid} = 1;    # Default to valid for most cases
   }
}

# Cache for Time::Moment objects
my %time_moment_cache;

# Test functions
sub test_validation {
   my ( $desc, $test ) = @_;
   my $is_valid      = $desc ? $desc->is_valid      : 0;
   my $error_message = $desc ? $desc->error_message : $_;

   # Strip file and line number from error message for comparison
   $error_message =~ s/ at \S+ line \d+\.?\s*$// if $error_message;
   my $ok = ok( $is_valid == $test->{is_valid}, $test->{is_valid} ? "Cron expression is valid" : "Cron expression is invalid" );
   if ( !$ok && $error_message && $test->{error_message} ) {
      diag "Error: $error_message";
      like( $error_message, qr/\Q$test->{error_message}\E/, "Error message matches: $test->{error_message}" );
   }
   return $ok;
}

sub test_fields {
   my ( $desc, $test ) = @_;
   if ( $test->{expected_fields} ) {
      cmp_deeply( $desc->to_hash, $test->{expected_fields}, "Fields match expected structure" );
   }
   else {
      pass("No expected fields to test");
   }
}

sub test_matches {
   my ( $desc, $test ) = @_;
   if ( $test->{matches} && @{ $test->{matches} } ) {
      foreach my $match ( @{ $test->{matches} } ) {
         my $ts     = $match->{timestamp};
         my $offset = $match->{utc_offset} // 0;
         $time_moment_cache{ $ts . "_" . $offset } //= Time::Moment->from_epoch($ts)->with_offset_same_instant($offset);
         my $tm = $time_moment_cache{ $ts . "_" . $offset };

         # Use the provided Cron::Describe object and update its utc_offset
         try {
            $desc->utc_offset($offset);
         }
         catch {
            diag "Failed to set utc_offset to $offset: $_";
            fail "Setting utc_offset for match test";
            next;
         };
         is( $desc->is_match($tm), $match->{matches}, sprintf( "Timestamp %s (%s) matches expected: %d with utc_offset=%s", $ts, $tm->strftime('%Y-%m-%d %H:%M:%S %z'), $match->{matches}, $offset ) );
      }
   }
   else {
      pass("No match tests defined");
   }
}

# Run tests
plan tests => scalar @all_tests;    # Updated to reflect dynamic count (52 tests)
my $test_number = 0;
foreach my $test (@all_tests) {
   $test_number++;
   my $test_desc = $test->{description} // ( $test->{is_valid} ? "Valid cron: $test->{expression}" : "Invalid cron: $test->{expression}" );
   subtest "Test $test_number: $test_desc" => sub {
      my $desc;
      my $exception;

      try {
         if ( $test->{tz} ) {
            $desc = Cron::Describe->new(expression => $test->{expression}, tz => $test->{tz});
         }
         else {
            $desc = Cron::Describe->new(expression => $test->{expression}, utc => 0);
         }
      }
      catch {
         if ( $test->{is_valid} ) {
            $exception = $_;
         }
         else {
            $desc = bless { is_valid => 0, error_message => $_ }, 'Cron::Describe';
         }
      };

      #try {
      #    $desc = Cron::Describe->new($test->{expression}, utc_offset => 0);
      #} catch {
      #    $exception = $_;
      #};

      # Consolidated diagnostic
      my $diag_msg = "Test Summary:\n";
      $diag_msg .= "  Original expression: $test->{expression}\n";
      $diag_msg .= "  Normalized expression: " . ( $desc                                            ? $desc->to_string : "N/A (failed to parse)" ) . "\n";
      $diag_msg .= "  Status: " .                ( $desc && $desc->is_valid                         ? "Valid"          : "Invalid" ) . "\n";
      $diag_msg .= "  Error: " .                 ( $exception                                       ? $exception       : ( $desc && $desc->error_message ? $desc->error_message : "None" ) ) . "\n";
      $diag_msg .= "  Expected: " .              ( $test->{is_valid}                                ? "Valid"          : "Invalid" ) . "\n";
      $diag_msg .= "  UTC Offset: " .            ( exists $test->{matches} && @{ $test->{matches} } ? join( ", ", map { $_->{utc_offset} // 0 } @{ $test->{matches} } ) : 0 ) . "\n";
      diag $diag_msg;

      # Validation test
      my $validation_passed = test_validation( $desc, $test );

      # Skip further tests if validation failed or expression is invalid
    SKIP: {
         skip "Skipping field and match tests for invalid expression", 2 unless $validation_passed && $desc && $desc->is_valid;

         # Field structure test
         test_fields( $desc, $test );

         # Timestamp matching test
         test_matches( $desc, $test );
      }
   };
}

done_testing();
