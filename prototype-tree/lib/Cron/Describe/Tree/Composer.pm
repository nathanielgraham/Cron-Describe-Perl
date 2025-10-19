package Cron::Describe::Tree::Composer;
use strict;
use warnings;
use Cron::Describe::Tree::Utils qw(
    num_to_ordinal join_parts %day_names format_time fill_template
);
sub new { bless {}, shift }

sub describe {
    my ($self, $root) = @_;
    my @fields = @{$root->{children}};
   
    # 🔥 FIXED: SAFE EXTRACTION (only for singles; undef for steps/wildcards)
    my $sec = ($fields[0]{type} eq 'single') ? $fields[0]{value} : undef;
    my $min = ($fields[1]{type} eq 'single') ? $fields[1]{value} : undef;
    my $hour = ($fields[2]{type} eq 'single') ? $fields[2]{value} : undef;
    my $time_prefix = format_time($sec // 0, $min // 0, $hour // 0);  # Default 0 for format only
    $time_prefix = "at $time_prefix" if $time_prefix;
   
    my @phrases;
    for my $field (@fields) {
        push @phrases, $self->template_for_field($field, \@fields);
    }
   
    # 🔥 FIXED: STEP PRIORITY
    my @time_phrases = grep { $_ } @phrases[0..2];
    my $time_str = join(' ', @time_phrases);
    return $time_str if $time_str =~ /^every \d+ (seconds|minutes|hours|from)/;
   
    my @date_phrases = grep { $_ } @phrases[3..6];
    my $date_str = join(' ', @date_phrases);
    $date_str = "on $date_str" if $date_str && $date_phrases[0] =~ /^(the|last)/;
   
    # 🔥 FIXED: MIDNIGHT ONLY IF ALL DEFINED SINGLES == 0
    if (defined $sec && defined $min && defined $hour && $sec == 0 && $min == 0 && $hour == 0) {
        $time_prefix = 'at midnight' . ($date_str ? ' ' : '');
    }
    return (join(' ', grep { $_ } ($time_prefix, $date_str)) || 'every second') =~ s/\s+/ /gr;
}

sub template_for_field {
    my ($self, $field, $fields) = @_;
    my $type = $field->{type};
    my $ft = $field->{field_type};
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
            # 🔥 FIXED: TEMPLATE MATCH (assume ft='minute'/'second')
            my $tmpl = ($ft eq 'minute' || $ft eq 'min') ? 'every_N_minute' 
                     : ($ft eq 'second' || $ft eq 'sec') ? 'every_N_second' 
                     : "every_N_$ft";
            return fill_template($tmpl, $data);
        } else {
            $data->{step} = $step;
            $data->{start} = $base->{children}[0]{value};
            $data->{end} = $base->{children}[1]{value};
            $data->{hour} = $fields->[2]{children}[0]{value} // 8;
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
    elsif ($type eq 'last' && $ft eq 'dom') {
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
    elsif ($ft eq 'year') {
        $data->{year} = $field->{value};
        return fill_template('year_in', $data);
    }
   
    return '';
}
1;
