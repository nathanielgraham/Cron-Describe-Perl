package Cron::Describe;
use strict;
use warnings;
use Cron::Describe::Tree::Utils qw(validate normalize);
use Cron::Describe::Tree::TreeParser;
use Cron::Describe::Tree::CompositePattern;
use Cron::Describe::Tree::Composer;  # 🔥 ADD THIS!

sub new {
    my ($class, %args) = @_;
    my $self = bless \%args, $class;
    
    # LAYER 1+2: NORMALIZE + VALIDATE
    my @fields = split /\s+/, normalize($self->{expression});
    my @types = qw(second minute hour dom month dow year);
    
    $self->{root} = Cron::Describe::Tree::CompositePattern->new(type => 'root');
    for my $i (0..6) {
        validate($fields[$i], $types[$i]);
        $self->{root}->add_child(Cron::Describe::Tree::TreeParser->parse_field($fields[$i], $types[$i]));
    }
    
    return $self;
}

sub describe {
    my $self = shift;
    my $composer = Cron::Describe::Tree::Composer->new;  # 🔥 NOW WORKS!
    return $composer->describe($self->{root});
}

1;
