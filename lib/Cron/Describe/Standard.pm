package Cron::Describe::Standard;
use strict;
use warnings;
use base 'Cron::Describe';

sub new {
    my ($class, %args) = @_;
    print STDERR "DEBUG: Standard.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n";
    my $self = $class->SUPER::new(%args);
    $self->{expression_type} = 'standard';
    return $self;
}

sub is_quartz {
    my $self = shift;
    print STDERR "DEBUG: Standard.pm is_quartz called\n";
    return 0;
}

sub to_english {
    my ($self) = @_;
    print STDERR "DEBUG: Standard.pm generating to_english\n";
    my @descs;
    for my $field (@{$self->{fields}}) {
        my $desc = $field->to_english;
        print STDERR "DEBUG: Field $field->{field_type} description: $desc\n";
        push @descs, $desc;
    }
    my ($min, $hour, $dom, $month, $dow) = @descs;
    my $min_val = $min =~ /^every minute$/ ? '00' : $min =~ /^every \d+ minutes/ ? sprintf("%02d", (split / /, $min)[1]) : $min;
    my $hour_val = $hour =~ /^every hour$/ ? '00' : $hour =~ /^every \d+ hours/ ? sprintf("%02d", (split / /, $hour)[1]) : $hour;
    my $time = ($min_val =~ /-/ || $min_val =~ /,/) ? $min_val : sprintf("%s:%s", $min_val, $hour_val);
    my @date_parts;
    for my $desc ($dom, $month, $dow) {
        my $type = $desc eq $dom ? 'day-of-month' : $desc eq $month ? 'month' : 'day-of-week';
        $desc = "every $type" if $desc =~ /^every / && $desc !~ /starting at/;
        push @date_parts, $desc;
    }
    my $result = "Runs at $time on " . join(', ', @date_parts);
    print STDERR "DEBUG: Final Standard description: $result\n";
    return $result;
}

1;
