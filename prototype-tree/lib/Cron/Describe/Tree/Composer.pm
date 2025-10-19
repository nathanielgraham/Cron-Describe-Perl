package Cron::Describe::Tree::Composer;
use strict;
use warnings;
use Cron::Describe::Tree::Utils qw(:all);

sub new { bless {}, shift }

sub describe {
    my ($self, $root) = @_;
    my @fields = @{$root->{children}};
    
    # 🔥 FIXED: SET field_type for ALL
    my @field_types = qw(second minute hour dom month dow year);
    for my $i (0..6) {
        $fields[$i]{field_type} = $field_types[$i] if $fields[$i];
    }
    
    my $sec = ($fields[0]{type} eq 'single') ? $fields[0]{value} : undef;
    my $min = ($fields[1]{type} eq 'single') ? $fields[1]{value} : undef;
    my $hour = ($fields[2]{type} eq 'single') ? $fields[2]{value} : undef;
    my $time_prefix = format_time($sec // 0, $min // 0, $hour // 0);
    $time_prefix = "at $time_prefix" if $time_prefix;

    my @phrases;
    for my $field (@fields) {
        push @phrases, $self->template_for_field($field, \@fields);
    }
    push @phrases, $time_prefix if $time_prefix;

    # 🔥 COMBO LOGIC - SIMPLIFIED!
    $self->_fuse_combos(\@phrases, \@fields);

    my @time_phrases = grep { $_ } @phrases[0..2];
    my $time_str = join(' ', @time_phrases);
    return $time_str if $time_str =~ /^every \d+ (seconds?|minutes?|hours?)/;

    my @date_phrases = grep { $_ } @phrases[3..6];
    my $date_str = join(' ', @date_phrases);
    $date_str = "on $date_str" if $date_str && $date_phrases[0] =~ /^(the|last)/;

    if (defined $sec && defined $min && defined $hour && $sec == 0 && $min == 0 && $hour == 0) {
        $time_prefix = 'at midnight' . ($date_str ? ' ' : '');
    }
    return (join(' ', grep { $_ } ($time_prefix, $date_str)) || 'every second') =~ s/\s+/ /gr;
}

sub _fuse_combos {
    my ($self, $phrases, $fields) = @_;
    
    # DOM Special + Month
    if ($phrases->[3] && $phrases->[4] && $fields->[3]{type} =~ /^(last|lastW|nearest_weekday|step)$/ ) {
        my $data = { dom_desc => $phrases->[3], month_range => $phrases->[4] };
        $phrases->[3] = fill_template('dom_special_month_range', $data);
        $phrases->[4] = '';
    }
    
    # DOW Nth + Month
    if ($phrases->[5] && $phrases->[4] && $fields->[5]{type} eq 'nth') {
        my ($day, $nth) = $fields->[5]{value} =~ /(\d+)#(\d+)/;
        my $data = { nth => num_to_ordinal($nth), day => $day_names{$day}, month_range => $phrases->[4] };
        $phrases->[5] = fill_template('dow_nth_month_range', $data);
        $phrases->[4] = '';
    }
    
    # DOM Single/List + Year
    if ($phrases->[3] && $phrases->[6] && $fields->[3]{type} eq 'single') {
        my $data = { ordinal => num_to_ordinal($fields->[3]{value}), year_start => $fields->[6]{children}[0]{value}, year_end => $fields->[6]{children}[1]{value} };
        $phrases->[3] = fill_template('dom_single_year_range', $data);
        $phrases->[6] = '';
    } elsif ($phrases->[3] && $phrases->[6] && $fields->[3]{type} eq 'list') {
        my $data = { list => $phrases->[3], year_start => $fields->[6]{children}[0]{value}, year_end => $fields->[6]{children}[1]{value} };
        $phrases->[3] = fill_template('dom_list_year_range', $data);
        $phrases->[6] = '';
    }
    
    # DOW Range/List + Year
    if ($phrases->[5] && $phrases->[6] && $fields->[5]{type} eq 'range') {
        my $data = { start => $day_names{$fields->[5]{children}[0]{value}}, end => $day_names{$fields->[5]{children}[1]{value}}, year_start => $fields->[6]{children}[0]{value}, year_end => $fields->[6]{children}[1]{value} };
        $phrases->[5] = fill_template('dow_range_year_range', $data);
        $phrases->[6] = '';
    } elsif ($phrases->[5] && $phrases->[6] && $fields->[5]{type} eq 'list') {
        my $data = { list => $phrases->[5], year_start => $fields->[6]{children}[0]{value}, year_end => $fields->[6]{children}[1]{value} };
        $phrases->[5] = fill_template('dow_list_year_range', $data);
        $phrases->[6] = '';
    }
    
    # Step on DOM + Month
    if ($phrases->[3] && $phrases->[4] && $fields->[3]{type} eq 'step') {
        my $data = { step => $fields->[3]{children}[1]{value}, start => num_to_ordinal($fields->[3]{children}[0]{children}[0]{value}), month_range => $phrases->[4] };
        $phrases->[3] = fill_template('dom_step_month_range', $data);
        $phrases->[4] = '';
    }
    
    # DOW Single + Month
    if ($phrases->[5] && $phrases->[4] && $fields->[5]{type} eq 'single') {
        my $data = { day => $day_names{$fields->[5]{value}}, month_range => $phrases->[4] };
        $phrases->[5] = fill_template('dow_single_month_range', $data);
        $phrases->[4] = '';
    }
    
    # DOW Range + Month
    if ($phrases->[5] && $phrases->[4] && $fields->[5]{type} eq 'range') {
        my $data = { start => $day_names{$fields->[5]{children}[0]{value}}, end => $day_names{$fields->[5]{children}[1]{value}}, month_range => $phrases->[4] };
        $phrases->[5] = fill_template('dow_range_month_range', $data);
        $phrases->[4] = '';
    }
    
    # DOW Special + Month
    if ($phrases->[5] && $phrases->[4] && $fields->[5]{type} eq 'last') {
        my $data = { day => $day_names{$fields->[5]{value}}, month_range => $phrases->[4] };
        $phrases->[5] = fill_template('dow_special_month_range', $data);
        $phrases->[4] = '';
    }
}

sub template_for_field {
    my ($self, $field, $fields) = @_;
    my $type = $field->{type};
    my $ft = $field->{field_type} // '';
    return '' if $type eq 'wildcard' || $type eq 'unspecified';

    my $data = {};

    if ($type eq 'single' && $ft eq 'dom') {
        $data->{ordinal} = num_to_ordinal($field->{value});
        return fill_template('dom_single_every', $data);
    }
    elsif ($type eq 'step') {
        my $step = $field->{children}[1]{value};
        my $base = $field->{children}[0];
        if ($base->{type} eq 'wildcard') {
            $data->{step} = $step;
            my $tmpl = "every_N_$ft";
            return fill_template($tmpl, $data);
        } else {
            $data->{step} = $step;
            $data->{start} = $base->{children}[0]{value};
            $data->{end} = $base->{children}[1]{value};
            $data->{hour} = $fields->[2]{value} // 8;
            return fill_template('step_range', $data);
        }
    }
    elsif ($type eq 'range' && $ft eq 'dom') {
        $data->{start} = num_to_ordinal($field->{children}[0]{value});
        $data->{end} = num_to_ordinal($field->{children}[1]{value});
        return fill_template('dom_range_every', $data);
    }
    elsif ($type eq 'list' && $ft eq 'dow') {
        my @days = map { $day_names{$_->{value}} } @{$field->{children}};
        $data->{list} = join_parts(@days);
        return fill_template('dow_list', $data);
    }
    elsif ($type eq 'list' && $ft eq 'dom') {
        my @ords = map { num_to_ordinal($_->{value}) } @{$field->{children}};
        $data->{list} = join_parts(@ords);
        return fill_template('dom_list', $data);
    }
    elsif ($type eq 'range' && $ft eq 'month') {
        $data->{start} = $month_names{$field->{children}[0]{value}};
        $data->{end} = $month_names{$field->{children}[1]{value}};
        return fill_template('month_range', $data);
    }
    elsif ($type eq 'single' && $ft eq 'month') {
        return "in " . $month_names{$field->{value}};
    }
    elsif ($type eq 'range' && $ft eq 'dow') {
        $data->{start} = $day_names{$field->{children}[0]{value}};
        $data->{end} = $day_names{$field->{children}[1]{value}};
        return fill_template('dow_range', $data);
    }
    elsif ($type eq 'single' && $ft eq 'dow') {
        $data->{day} = $day_names{$field->{value}};
        return fill_template('dow_single', $data);
    }
    elsif ($type eq 'last' && $ft eq 'dom') {
        if ($field->{value} =~ /L-(\d+)/) {
            $data->{ordinal} = num_to_ordinal($1);
            return fill_template('dom_last_offset', $data);
        }
        return fill_template('dom_last', $data);
    }
    elsif ($type eq 'lastW' && $ft eq 'dom') {
        return fill_template('dom_lw', $data);
    }
    elsif ($type eq 'nth' && $ft eq 'dow') {
        my ($day, $nth) = $field->{value} =~ /(\d+)#(\d+)/;
        $data->{nth} = num_to_ordinal($nth);
        $data->{day} = $day_names{$day};
        return fill_template('dow_nth', $data);
    }
    elsif ($type eq 'nearest_weekday' && $ft eq 'dom') {
        my ($day) = $field->{value} =~ /(\d+)W/;
        $data->{ordinal} = num_to_ordinal($day);
        return fill_template('dom_nearest_weekday', $data);
    }
    elsif ($type eq 'single' && $ft eq 'year') {
        $data->{year} = $field->{value};
        return fill_template('year_in', $data);
    }
    elsif ($type eq 'range' && $ft eq 'year') {
        $data->{start} = $field->{children}[0]{value};
        $data->{end} = $field->{children}[1]{value};
        return fill_template('year_range', $data);
    }
    return '';
}

1;
