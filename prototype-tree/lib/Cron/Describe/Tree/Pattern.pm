package Cron::Describe::Tree::Pattern;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::Tree::EnglishVisitor;
use Cron::Describe::Tree::MatchVisitor;

sub new {
    my ($class, %args) = @_;
    my $self = bless {
        type => $args{type} // croak "type required",
        children => [],
    }, $class;
    return $self;
}

sub add_child {
    my ($self, $child) = @_;
    push @{$self->{children}}, $child;
}

sub get_children {
    my ($self) = @_;
    return @{$self->{children}};
}

sub traverse {
    my ($self, $visitor) = @_;
    my @child_results = map { $_->traverse($visitor) } @{$self->{children}};
    return $visitor->visit($self, @child_results);
}

sub is_match {
    my ($self, $value, $tm) = @_;
    my $visitor = Cron::Describe::Tree::MatchVisitor->new(value => $value, tm => $tm);
    return $self->traverse($visitor);
}

sub to_english {
    my ($self, $field_type) = @_;
    my $visitor = Cron::Describe::Tree::EnglishVisitor->new(field_type => $field_type);
    return $self->traverse($visitor);
}

sub dump_tree {
    my ($node, $indent) = @_;
    $indent //= 0;  # Default to 0 if undef
    my $prefix = '  ' x $indent;
    print $prefix, "Type: ", $node->{type}, ", Value: '", $node->{value} || '', "'\n";
    for my $child (@{$node->{children} || []}) {
        dump_tree($child, $indent + 1);
    }
}

1;
