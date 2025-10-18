package Cron::Describe;
use strict;
use warnings;
use Cron::Describe::Tree::TreeParser;
use Cron::Describe::Tree::Composer;

sub new {
    my ($class, %args) = @_;
    my $self = bless {%args}, $class;

    my @fields = split /\s+/, $self->{expression};
    my @types  = qw(second minute hour dom month dow year);
    my $root   = Cron::Describe::Tree::Pattern->new(type => 'root');
    for my $i (0 .. $#fields) {
        my $node = Cron::Describe::Tree::TreeParser->parse_field($fields[$i], $types[$i]);
        $node->{field_type} = $types[$i];
        $root->add_child($node);
    }
    $self->{root} = $root;
    return $self;
}

sub describe {
    my $self = shift;
    my $composer = Cron::Describe::Tree::Composer->new();
    return $composer->describe($self->{root});
}

1;
