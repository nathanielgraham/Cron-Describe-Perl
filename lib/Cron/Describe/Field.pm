# ABSTRACT: Base class for validating and describing cron expression fields
package Cron::Describe::Field;

use strict;
use warnings;
use Moo;
use Carp qw(croak);

has 'value'       => (is => 'ro', required => 1);
has 'min'         => (is => 'ro', required => 1);
has 'max'         => (is => 'ro', required => 1);
has 'allowed_specials' => (is => 'ro', default => sub { ['*', ',', '-', '/'] });
has 'allowed_names' => (is => 'ro', default => sub { {} });  # For month/day names

sub is_valid {
    my ($self) = @_;
    my $val = $self->value;
    my %errors;

    # Validate against allowed specials and names
    my $specials = join '|', map { quotemeta } @{$self->allowed_specials};
    my $names = join '|', keys %{$self->allowed_names};
    my $num_regex = qr/\d+/;
    my $range_regex = qr/(?:$num_regex|$names)-(?:$num_regex|$names)/;
    my $list_regex = qr/(?:$num_regex|$names|$range_regex)(?:,(?:$num_regex|$names|$range_regex))*/;
    my $step_regex = qr/(?:\*|$num_regex|$range_regex|$list_regex)\/(\d+)/;

    unless ($val =~ m{
        ^ (?: \* (?: / \d+ )? 
          | $range_regex (?: / \d+ )? 
          | $list_regex 
          | $num_regex
          | $names
          | $specials
        ) $
    }x) {
        $errors{syntax} = "Invalid syntax in field: $val";
    } else {
        # Check numeric ranges
        if ($val =~ /(\d+)/) {
            my @nums = ($val =~ /(\d+)/g);
            for my $num (@nums) {
                if ($num < $self->min || $num > $self->max) {
                    $errors{range} = "Value $num out of range [$self->min-$self->max]";
                }
            }
        }
        # Check step values
        if ($val =~ $step_regex) {
            my $step = $1;
            if ($step == 0) {
                $errors{step} = "Step value cannot be zero: $val";
            }
        }
    }

    return (scalar keys %errors == 0, \%errors);
}

sub describe {
    my ($self, $unit) = @_;
    my $val = $self->value;
    my $names = join '|', keys %{$self->allowed_names};

    if ($val eq '*') {
        return 'every';
    } elsif ($val =~ /^(\d+)$/) {
        return "at $1 $unit" . ($1 == 1 && $unit ne 'month' ? '' : 's');
    } elsif ($val =~ /^(\d+)-(\d+)$/) {
        return "from $1 to $2 $unit" . ($2 == 1 && $unit ne 'month' ? '' : 's');
    } elsif ($val =~ /^(?:(?:\d+|$names)(?:,(?:\d+|$names))*)$/) {
        my @parts = split /,/, $val;
        my @desc = map { $self->allowed_names->{$_} ? lc($_) : $_ } @parts;
        return "at " . join(', ', @desc) . " $unit" . (@desc == 1 && $unit ne 'month' ? '' : 's');
    } elsif ($val =~ /^(.*?)(?:\/(\d+))$/) {
        my ($base, $step) = ($1, $2);
        my $base_desc = $base eq '*' ? 'every' : $self->new(value => $base, min => $self->min, max => $self->max)->describe($unit);
        return "every $step $unit" . ($step == 1 && $unit ne 'month' ? '' : 's') . ($base eq '*' ? '' : " $base_desc");
    } elsif ($self->allowed_names->{$val}) {
        return lc $val;
    }

    return $val;  # Fallback for special characters
}

1;

__END__

=pod

=head1 NAME

Cron::Describe::Field - Base class for validating and describing cron expression fields

=head1 DESCRIPTION

Handles generic field validation and description for cron expressions.

=head1 METHODS

=over 4

=item is_valid

Returns (boolean, \%errors) indicating if the field is valid.

=item describe($unit)

Returns a concise English description of the field value (e.g., 'every minutes', 'at 5 minutes', 'from 1 to 5 hours').

=back

=head1 AUTHOR

Nathaniel Graham <ngraham@cpan.org>

=head1 LICENSE

This is released under the Artistic License 2.0.

=cut
```

**Changes**:
- Added `my $names = join '|', keys %{$self->allowed_names};` in the `describe` method to declare the `$names` variable, fixing the "Global symbol" error at line 70.
- No changes to `is_valid`, as it’s correct and unaffected.

#### File: t/validate.t
<xaiArtifact artifact_id="46a842cb-dcef-4900-95cc-378194c6306e" artifact_version_id="f3b2681e-b023-4cc2-b28d-911179b70e12" title="t/validate.t" contentType="text/plain">
# Tests for standard UNIX cron expressions
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

subtest 'Constructor dispatch' => sub {
    plan tests => 4;

    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    isa_ok($cron, 'Cron::Describe::Standard', '5 fields -> Standard');
    
    eval { Cron::Describe->new(cron_str => '0 0 * * *', type => 'standard') };
    ok(!$@, 'Explicit standard type');
    
    my $cron2 = Cron::Describe->new(cron_str => '0 0 * * * ?');
    my ($valid, $errors) = $cron2->is_valid;
    ok(!$valid, 'Quartz chars in standard type');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Quartz chars in standard type error');
};

subtest 'Field parsing' => sub {
    plan tests => 8;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0,15 * * 1');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid fields: list, numeric day') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0,15 hours, mon day', 'Description for list, numeric day');

    $cron = Cron::Describe->new(cron_str => '*/15 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid step: */15') or diag explain $errors;
    is($cron->describe, 'every 15 minutes, at 0 hours', 'Description for step');

    $cron = Cron::Describe->new(cron_str => '60 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid minute');
    like($errors->{range}, qr/Value 60 out of range/i, 'Invalid minute error');

    $cron = Cron::Describe->new(cron_str => '0 0 * 13 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid month');
    like($errors->{range}, qr/Value 13 out of range/i, 'Invalid month error');

    $cron = Cron::Describe->new(cron_str => '0 0 * BAD *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid month name');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Invalid month name error');
};

subtest 'Easy cases' => sub {
    plan tests => 4;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic hourly standard') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours', 'Description for hourly');

    $cron = Cron::Describe->new(cron_str => '0 0,15 * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard list') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0,15 hours', 'Description for list');
};

subtest 'Medium cases' => sub {
    plan tests => 6;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Standard range') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours, from 1 to 5 days', 'Description for range');

    $cron = Cron::Describe->new(cron_str => '0 0 * JAN,FEB MON-WED');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Month and day names') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours, jan,feb months, mon-wed days', 'Description for names');

    $cron = Cron::Describe->new(cron_str => '0 0 31 4 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 31 invalid for 4/, 'Invalid day for April error');
};

subtest 'Edge cases' => sub {
    plan tests => 8;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 * 15 * MON');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'DayOfMonth and DayOfWeek conflict');
    like($errors->{conflict}, qr/both be specified/i, 'DayOfMonth and DayOfWeek conflict error');

    $cron = Cron::Describe->new(cron_str => '0 0 29 2 *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29)') or diag explain $errors;
    is($cron->describe, 'at 0 minutes, at 0 hours, at 29 days, feb month', 'Description for leap year');

    $cron = Cron::Describe->new(cron_str => '0 0 * * *#2');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Quartz # in standard');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Quartz # in standard error');

    $cron = Cron::Describe->new(cron_str => '0 0 30 4 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 30 invalid for 4/, 'Invalid day for April error');
};

subtest 'Unusual patterns' => sub {
    plan tests => 12;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '1,3-5/2 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Combined list and range with step') or diag explain $errors;
    is($cron->describe, 'at 1, every 2 minutes from 3 to 5', 'Description for list and range with step');

    $cron = Cron::Describe->new(cron_str => '*/0 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Zero step');
    like($errors->{step}, qr/Step value cannot be zero/, 'Zero step error');

    $cron = Cron::Describe->new(cron_str => '-1 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Negative number');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Negative number error');

    $cron = Cron::Describe->new(cron_str => 'a * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Non-numeric');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Non-numeric error');

    $cron = Cron::Describe->new(cron_str => '1-5/2,10 * * * *');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Range with step and list') or diag explain $errors;
    is($cron->describe, 'every 2 minutes from 1 to 5, at 10 minutes', 'Description for range with step and list');

    $cron = Cron::Describe->new(cron_str => '0 0 1,15,30 4 *');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day list for April');
    like($errors->{range}, qr/Days 30 invalid for 4/, 'Invalid day list for April error');
};

done_testing;
```

**Changes**:
- Removed stray text (e.g., "- Added `") that caused the syntax error at line 150. The file is now based on the clean version from November 11, 2025.
- Verified all `$valid` and `$errors` variables are declared with `my` once per subtest scope to prevent redeclaration or undefined errors.

#### File: t/validate_quartz.t
<xaiArtifact artifact_id="8028e5e6-69f1-462b-896b-ce5ae1276c25" artifact_version_id="24b1c95e-f3bf-4984-a71c-4f976ae37fc5" title="t/validate_quartz.t" contentType="text/plain">
# Tests for Quartz Scheduler cron expressions
use strict;
use warnings;
use Test::More;
use Try::Tiny;

use Cron::Describe;

subtest 'Constructor dispatch' => sub {
    plan tests => 4;

    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?');
    isa_ok($cron, 'Cron::Describe::Quartz', '6 fields -> Quartz');

    eval { Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz') };
    ok(!$@, 'Explicit quartz type');

    my $cron2 = Cron::Describe->new(cron_str => '0 0 * * *');
    my ($valid, $errors) = $cron2->is_valid;
    ok(!$valid, 'Too few fields for Quartz');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Too few fields for Quartz error');
};

subtest 'Field parsing' => sub {
    plan tests => 12;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 12 L * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, last day of the month, every day-of-week', 'Description for L');

    $cron = Cron::Describe->new(cron_str => '0 0 12 15W * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid W in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, nearest weekday to the 15th, every day-of-week', 'Description for W');

    $cron = Cron::Describe->new(cron_str => '0 0 12 ? * MON#2');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid # in DayOfWeek') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, the 2nd mon day', 'Description for #');

    $cron = Cron::Describe->new(cron_str => '0 0 12 ? * BAD#2');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid # syntax');
    like($errors->{syntax}, qr/Invalid # syntax/, 'Invalid # syntax error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 32 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid DayOfMonth');
    like($errors->{range}, qr/Value 32 out of range/i, 'Invalid DayOfMonth error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?', type => 'quartz', timezone => 'Invalid/TZ');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid timezone');
    like($errors->{timezone}, qr/Invalid timezone/, 'Invalid timezone error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 32W * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid W value');
    like($errors->{range}, qr/W value 32 out of range/, 'Invalid W value error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-32 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid L offset');
    like($errors->{range}, qr/L offset 32 out of range/, 'Invalid L offset error');
};

subtest 'Easy cases' => sub {
    plan tests => 4;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 12 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Basic daily Quartz') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, every day-of-week', 'Description for daily');

    $cron = Cron::Describe->new(cron_str => '0 0,15 12 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz list') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0,15 minutes, at 12 hours, every day-of-month, every day-of-week', 'Description for list');
};

subtest 'Medium cases' => sub {
    plan tests => 6;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 1-5 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz range') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, from 1 to 5 hours, every day-of-month, every day-of-week', 'Description for range');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * JAN,FEB ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Quartz month names') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, jan,feb months, every day-of-week', 'Description for month names');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * BAD ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid month name');
    like($errors->{syntax}, qr/Invalid syntax in field: BAD/, 'Invalid month name error');
};

subtest 'Edge cases' => sub {
    plan tests => 10;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 0 ? 2 2#5');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Impossible fifth Monday in Feb');
    like($errors->{impossible}, qr/Fifth weekday in February/, 'Impossible fifth Monday in Feb error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 29 * ? 2024');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Leap year day (Feb 29, 2024)') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, at 29 days, every day-of-week, at 2024 years', 'Description for leap year');

    $cron = Cron::Describe->new(cron_str => '0 0 12 15 * MON');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'DayOfMonth and DayOfWeek conflict');
    like($errors->{conflict}, qr/Either DayOfMonth or DayOfWeek must be \?/, 'DayOfMonth and DayOfWeek conflict error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 30 4 ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 30 invalid for 4/, 'Invalid day for April error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-3 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L-3 in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, 3 days before the last day of the month, every day-of-week', 'Description for L-3');
};

subtest 'Unusual patterns' => sub {
    plan tests => 18;

    my ($valid, $errors);
    my $cron = Cron::Describe->new(cron_str => '0 0 12 1,3-5/2 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Combined list and range with step') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, at 1, every 2 days from 3 to 5, every day-of-week', 'Description for list and range with step');

    $cron = Cron::Describe->new(cron_str => '*/0 * * * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Zero step');
    like($errors->{step}, qr/Step value cannot be zero/, 'Zero step error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 -1 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Negative number');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Negative number error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 a * ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Non-numeric');
    like($errors->{syntax}, qr/Invalid syntax/i, 'Non-numeric error');

    $cron = Cron::Describe->new(cron_str => '0 0 12 30 4 ?');
    ($valid, $errors) = $cron->is_valid;
    ok(!$valid, 'Invalid day for April');
    like($errors->{range}, qr/Day 30 invalid for 4/, 'Invalid day for April error');

    $cron = Cron::Describe->new(cron_str => '1-5/2,10 0 12 * * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Range with step and list') or diag explain $errors;
    is($cron->describe, 'every 2 seconds from 1 to 5, at 10 seconds, at 0 minutes, at 12 hours, every day-of-month, every day-of-week', 'Description for range with step and list');

    $cron = Cron::Describe->new(cron_str => '0 0 12 ? * 1,2');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Multiple days of week') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, mon,tue days', 'Description for multiple days');

    $cron = Cron::Describe->new(cron_str => '0 0 12 * * L 2023');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Last Saturday in year') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, every day-of-month, last Saturday, at 2023 years', 'Description for L and year');

    $cron = Cron::Describe->new(cron_str => '0 1-5/2 12 1-3,15 JAN,FEB ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Complex combined pattern') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, every 2 minutes from 1 to 5, at 12 hours, at 1,2,3,15 days, jan,feb months, every day-of-week', 'Description for complex pattern');

    $cron = Cron::Describe->new(cron_str => '0 0 12 L-0 * ?');
    ($valid, $errors) = $cron->is_valid;
    ok($valid, 'Valid L-0 in DayOfMonth') or diag explain $errors;
    is($cron->describe, 'at 0 seconds, at 0 minutes, at 12 hours, last day of the month, every day-of-week', 'Description for L-0');
};

done_testing;
