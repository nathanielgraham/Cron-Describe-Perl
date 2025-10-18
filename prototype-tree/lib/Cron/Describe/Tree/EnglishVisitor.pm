package Cron::Describe::Tree::EnglishVisitor;
use parent 'Cron::Describe::Tree::Visitor';
use Cron::Describe::Tree::Utils qw(:all);

sub visit {
    my ($self, $node, @child_results) = @_;
    my $data = {
        field_type    => $self->{field_type},
        node          => $node,
        child_results => \@child_results,
    };

    # ------------------------------------------------------------------
    # 1. Single value (minute, hour, second, year, dom, dow)
    # ------------------------------------------------------------------
    if ($node->{type} eq 'single') {
        my $v = $node->{value};

        if ($data->{field_type} eq 'dow') {
            $data->{day} = $day_names{$v} || $v;
            $self->{result} = fill_template('dow_single', $data);
        }
        elsif ($data->{field_type} eq 'dom') {
            $data->{ordinal} = num_to_ordinal($v);
            $self->{result} = fill_template('dom_single_every', $data);
        }
        elsif ($data->{field_type} eq 'year') {
            $data->{year} = $v;
            $self->{result} = fill_template('year_in', $data);
        }
        else {
            # minute / hour / second – just the number (composer will format)
            $self->{result} = $v;
        }

    # ------------------------------------------------------------------
    # 2. Wild-card – we *omit* it from the final sentence
    # ------------------------------------------------------------------
    } elsif ($node->{type} eq 'wildcard' || $node->{type} eq 'unspecified') {
        $self->{result} = '';          # nothing to say

    # ------------------------------------------------------------------
    # 3. Range (dom only for now)
    # ------------------------------------------------------------------
    } elsif ($node->{type} eq 'range') {
        if ($data->{field_type} eq 'dom') {
            $data->{start} = num_to_ordinal($node->{children}[0]->{value});
            $data->{end}   = num_to_ordinal($node->{children}[1]->{value});
            $self->{result} = fill_template('dom_range_every', $data);
        } else {
            $self->{result} = '';      # unsupported for now – will be empty
        }

    # ------------------------------------------------------------------
    # 4. Step
    # ------------------------------------------------------------------
    } elsif ($node->{type} eq 'step') {
        my $base_node = $node->{children}[0];
        my $step_node = $node->{children}[1];
        $data->{step} = $step_node->{value};

        if ($base_node->{type} eq 'wildcard') {
            # “every N seconds/minutes”
            my $unit = $data->{field_type} eq 'second' ? 'seconds'
                     : $data->{field_type} eq 'minute' ? 'minutes'
                     : $data->{field_type};
            $data->{unit} = plural_unit($unit, $data->{step});
            my $tmpl = 'every_N_' . $data->{field_type};
            $self->{result} = fill_template($tmpl, $data);
        } else {
            # step over a range – e.g. “every 5 minutes from 10 to 20”
            my $range = $base_node;
            $data->{start} = $range->{children}[0]->{value};
            $data->{end}   = $range->{children}[1]->{value};
            $data->{hour}  = $self->{cron}{root}{children}[2]{value} || '';
            $self->{result} = fill_template('step_range', $data);
        }

    # ------------------------------------------------------------------
    # 5. List (dow only for now)
    # ------------------------------------------------------------------
    } elsif ($node->{type} eq 'list') {
        my @days = map { $day_names{$_} || $_ } @child_results;
        $data->{list} = join_parts(@days);
        $self->{result} = $data->{list};     # composer will prepend “on”

    # ------------------------------------------------------------------
    # 6. Special Quartz tokens
    # ------------------------------------------------------------------
    } elsif ($node->{type} eq 'last') {
        $self->{result} = fill_template('dom_last', $data);
    } elsif ($node->{type} eq 'lastW') {
        $self->{result} = fill_template('dom_lw', $data);
    } elsif ($node->{type} eq 'nth') {
        my ($day, $nth) = $node->{value} =~ /(\d+)#(\d+)/;
        $data->{nth} = num_to_ordinal($nth);
        $data->{day} = $day_names{$day};
        $self->{result} = fill_template('dow_nth', $data);
    } elsif ($node->{type} eq 'nearest_weekday') {
        my ($day) = $node->{value} =~ /(\d+)W/;
        $self->{result} = "nearest weekday to the " . num_to_ordinal($day) . " of the month";
    } else {
        $self->{result} = '';
    }

    # ------------------------------------------------------------------
    # 7. Midnight shortcut – only for fields that can contribute a time
    # ------------------------------------------------------------------
    if ($self->{field_type} =~ /^(dom|dow|year)$/) {
        my $sec = $self->{cron}{root}{children}[0]{value} // 0;
        my $min = $self->{cron}{root}{children}[1]{value} // 0;
        if ($sec == 0 && $min == 0) {
            $self->{result} = "at midnight " . $self->{result};
        }
    }

    return $self->{result};
}

1;
