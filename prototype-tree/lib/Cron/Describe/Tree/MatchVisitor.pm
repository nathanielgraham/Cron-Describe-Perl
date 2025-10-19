package Cron::Describe::Tree::MatchVisitor;
use parent 'Cron::Describe::Tree::Visitor';

sub new {
    my ($class, %args) = @_;
    $args{value} //= 0;
    $args{tm} //= undef;
    return $class->SUPER::new(%args);
}

sub visit {
    my ($self, $node, @child_results) = @_;
    if ($node->{type} eq 'single') {
        $self->{result} = ($self->{value} == $node->{value} ? 1 : 0);
    } elsif ($node->{type} eq 'wildcard') {
        $self->{result} = 1;
    } elsif ($node->{type} eq 'range') {
        $self->{result} = ($self->{value} >= $child_results[0] && $self->{value} <= $child_results[1]) ? 1 : 0;
    } elsif ($node->{type} eq 'step') {
       my $base_result = $child_results[0];  # 1 for wildcard
       my $step = $child_results[1];
       $self->{result} = (($self->{value} % $step == 0) ? 1 : 0) if $base_result == 1;
       # my $base_result = $child_results[0];
       # my $step = $child_results[1];
       # $self->{result} = (($self->{value} - $base_result) % $step == 0) ? 1 : 0;
    } elsif ($node->{type} eq 'list') {
        $self->{result} = (grep { $_ } @child_results) ? 1 : 0;
    } elsif ($node->{type} eq 'unspecified') {
        $self->{result} = 1;
    } else {
        $self->{result} = 1;
    }
    return $self->{result};
}

1;
