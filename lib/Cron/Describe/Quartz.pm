package Cron::Describe::Quartz;
use strict;
use warnings;
use base 'Cron::Describe';

sub new {
    my ($class, %args) = @_;
    print STDERR "DEBUG: Quartz.pm loaded (mtime: " . (stat(__FILE__))[9] . ")\n";
    my $self = $class->SUPER::new(%args);
    $self->{expression_type} = 'quartz';
    return $self;
}

sub is_quartz {
    my $self = shift;
    print STDERR "DEBUG: Quartz.pm is_quartz called\n";
    return 1;
}

sub to_english {
    my ($self) = @_;
    print STDERR "DEBUG: Quartz.pm generating to_english\n";
    my @descs;
    for my $field (@{$self->{fields}}) {
        my $desc = $field->to_english;
        print STDERR "DEBUG: Field $field->{field_type} description: $desc\n";
        push @descs, $desc;
    }
    my ($sec, $min, $hour, $dom, $month, $dow, $year) = @descs;
    my $time = sprintf("%02d:%02d:%02d", $sec =~ /^every second$/ ? 0 : $sec, $min =~ /^every minute$/ ? 0 : $min, $hour =~ /^every hour$/ ? 0 : $hour);
    my @date_parts;
    for my $desc ($dom, $month, $dow, $year) {
        next if !defined $desc;  # Skip undefined (e.g., year in 6-field Quartz)
        my $type = $desc eq $dom ? 'day-of-month' : $desc eq $month ? 'month' : $desc eq $dow ? 'day-of-week' : 'year';
        $desc = "every $type" if $desc =~ /^every /;
        push @date_parts, $desc;
    }
    my $result = "Runs at $time on " . join(', ', @date_parts);
    print STDERR "DEBUG: Final Quartz description: $result\n";
    return $result;
}

1;
