package Cron::Describe::Tree::TreeParser;
use strict;
use warnings;
use Cron::Describe::Tree::CompositePattern;
use Cron::Describe::Tree::LeafPattern;
use Cron::Describe::Tree::Utils qw(validate);  # 🔥 ADD THIS!
use Carp qw(croak);

sub parse_field {
    my ($class, $field, $field_type) = @_;
    return unless defined $field && $field ne '';
    validate($field, $field_type);  # 🔥 CHANGE THIS LINE!
    print STDERR "DEBUG PARSER: '$field' ($field_type)\n";
    
    # [REST OF YOUR EXISTING CODE - UNCHANGED!]
    if ($field eq '*') {
        return Cron::Describe::Tree::LeafPattern->new(type => 'wildcard', value => '*');
    } elsif ($field eq '?') {
        return Cron::Describe::Tree::LeafPattern->new(type => 'unspecified', value => '?');
    } elsif ($field =~ /^L(W?)(-\d+)?$/) {
        return Cron::Describe::Tree::LeafPattern->new(type => "last$1", value => $field);
    } elsif ($field =~ /^\d+$/) {
        return Cron::Describe::Tree::LeafPattern->new(type => 'single', value => $field);
    } elsif ($field =~ /^(\d+)#(\d+)$/) {
        return Cron::Describe::Tree::LeafPattern->new(type => 'nth', value => $field);
    } elsif ($field =~ /^(\d+)W$/) {
        return Cron::Describe::Tree::LeafPattern->new(type => 'nearest_weekday', value => $field);
    } elsif ($field =~ /^\*\/(\d+)$/) {
        my $step = Cron::Describe::Tree::CompositePattern->new(type => 'step');
        $step->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'wildcard', value => '*'));
        $step->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'step_value', value => $1));
        return $step;
    } elsif ($field =~ /^(\d+)\/(\d+)$/) {
        my $step = Cron::Describe::Tree::CompositePattern->new(type => 'step');
        $step->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'single', value => $1));
        $step->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'step_value', value => $2));
        return $step;
    } elsif ($field =~ /^(\*|\d+)-(\d+)\/(\d+)$/) {
        my $range = Cron::Describe::Tree::CompositePattern->new(type => 'range');
        $range->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'start', value => $1));
        $range->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'end', value => $2));
        my $step = Cron::Describe::Tree::CompositePattern->new(type => 'step');
        $step->add_child($range);
        $step->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'step_value', value => $3));
        return $step;
    } elsif ($field =~ /^(\d+)-(\d+)$/) {
        my $range = Cron::Describe::Tree::CompositePattern->new(type => 'range');
        $range->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'single', value => $1));
        $range->add_child(Cron::Describe::Tree::LeafPattern->new(type => 'single', value => $2));
        return $range;
    } elsif ($field =~ /,/) {
        my $list = Cron::Describe::Tree::CompositePattern->new(type => 'list');
        for my $sub (split /,/, $field) {
            $list->add_child($class->parse_field($sub, $field_type));
        }
        return $list;
    }
    croak "Unsupported field: $field ($field_type)";
}

1;
