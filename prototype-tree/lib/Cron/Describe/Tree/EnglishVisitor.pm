package Cron::Describe::Tree::EnglishVisitor;
use parent 'Cron::Describe::Tree::Visitor';
use Cron::Describe::Tree::Utils qw(:all);
sub visit {
    my ($self, $node, @child_results) = @_;
    my $data = { field_type => $self->{field_type}, node => $node, child_results => \@child_results };
    if ($node->{type} eq 'single') {
        $data->{value} = $node->{value};
        if ($data->{field_type} eq 'dow') {
            $data->{day} = $day_names{$data->{value}} || $data->{value};
            $self->{result} = fill_template('dow_single', $data);
        } elsif ($data->{field_type} eq 'dom') {
            $data->{ordinal} = num_to_ordinal($data->{value});
            $self->{result} = fill_template('dom_single_every', $data);
        } elsif ($data->{field_type} eq 'year') {
            $data->{year} = $data->{value};
            $self->{result} = fill_template('year_in', $data);
        } else {
            $self->{result} = $data->{value};
        }
    } elsif ($node->{type} eq 'wildcard') {
        $self->{result} = fill_template('every_day', $data);
    } elsif ($node->{type} eq 'range') {
        $data->{start} = num_to_ordinal($node->{children}[0]->{value});
        $data->{end} = num_to_ordinal($node->{children}[1]->{value});
        $self->{result} = fill_template('dom_range_every', $data) if $data->{field_type} eq 'dom';
    } elsif ($node->{type} eq 'step') {
        my $base_node = $node->{children}[0];
        my $step_node = $node->{children}[1];
        $data->{step} = $step_node->{value};
        $data->{start} = $base_node->{children}[0]->{value};
        $data->{end} = $base_node->{children}[1]->{value};
        $data->{unit} = plural_unit($data->{field_type}, $data->{step});
        if ($data->{field_type} eq 'second') {
            $self->{result} = fill_template('every_N_sec', $data);
        } elsif ($data->{field_type} eq 'minute') {
            $self->{result} = fill_template('every_N_min', $data);
        } else {
            $self->{result} = fill_template('step_range', $data);
        }
    } elsif ($node->{type} eq 'list') {
        my @days = map { $day_names{$_} } @child_results;
        $data->{list} = join_parts(@days);
        $self->{result} = fill_template('dow_list', $data) if $data->{field_type} eq 'dow';
    } elsif ($node->{type} eq 'last') {
        $self->{result} = fill_template('dom_last', $data);
    } elsif ($node->{type} eq 'lastW') {
        $self->{result} = fill_template('dom_lw', $data);
    } elsif ($node->{type} eq 'nth') {
        my ($day, $nth) = $node->{value} =~ /(\d+)#(\d+)/;
        $data->{nth} = num_to_ordinal($nth);
        $data->{day} = $day_names{$day};
        $self->{result} = fill_template('dow_nth', $data);
    } else {
        $self->{result} = '';
    }
    # Time prefix for dom/dow/year only
    if ($self->{field_type} =~ /^(dom|dow|year)$/) {
        my $sec = $self->{cron}->{root}->{children}[0]->{value} || 0;
        my $min = $self->{cron}->{root}->{children}[1]->{value} || 0;
        if ($sec == 0 && $min == 0) {
            $self->{result} = "at midnight " . $self->{result};
        }
    }
    return $self->{result};
}
1;
