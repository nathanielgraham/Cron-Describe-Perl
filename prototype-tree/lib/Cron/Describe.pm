package Cron::Describe;
use strict;
use warnings;
use Carp qw(croak);
use Cron::Describe::Tree::TreeParser;
use Cron::Describe::Tree::CompositePattern;
use Cron::Describe::Tree::Visitor;

sub new {
    my ($class, %args) = @_;
    my $expression = $args{expression} // croak "expression required";
    my @fields = split /\s+/, $expression;
    my $root = Cron::Describe::Tree::CompositePattern->new(type => 'root');
    my @field_types = qw(second minute hour dom month dow year);
    @fields = (0, @fields) if @fields == 5;
    @fields = (@fields, '*') if @fields == 6;
    for my $i (0..6) {
        my $subtree = Cron::Describe::Tree::TreeParser->parse_field($fields[$i], $field_types[$i]);
        $root->add_child($subtree);
    }
    my $self = bless { root => $root, field_types => \@field_types }, $class;
    return $self;
}

sub is_match {
    my ($self, $tm) = @_;
    my @method_names = qw(second minute hour day_of_month month day_of_week year);
    for my $i (0..6) {
        my $value = $tm->${ $method_names[$i] }();
        my @children = $self->{root}->get_children;
        return 0 unless $children[$i]->is_match($value, $tm);
    }
    return 1;
}

sub to_english {
    my ($self) = @_;
    my @priority = (1,0,5,3,2,4,6); # minute, second, dow, dom, hour, month, year
    my @children = $self->{root}->get_children;
    for my $i (@priority) {
        my $desc = $children[$i]->to_english($self->{field_types}[$i]);
        if ($desc && $desc ne "every $self->{field_types}[$i]") {
            return $desc;
        }
    }
    return "every minute";
}

1;
