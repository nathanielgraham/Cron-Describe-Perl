package Cron::Toolkit;

# ABSTRACT: Cron parser, describer, and scheduler with full Quartz support
# VERSION
$VERSION = 0.08;
use strict;
use warnings;
use Time::Moment;
use Cron::Toolkit::Utils qw(:all);
use Cron::Toolkit::Pattern::CompositePattern;
use Cron::Toolkit::Pattern::LeafPattern;
use Cron::Toolkit::Composer;
use Cron::Toolkit::Matcher;
use List::Util qw(max min);
use Exporter   qw(import);
use feature 'say';
use Data::Dumper;

=head1 NAME
Cron::Toolkit - Cron parser, describer, and scheduler with full Quartz support
=cut

sub new_from_unix {
   my ( $class, %args ) = @_;
   $args{is_quartz} = 0;
   my $self = $class->_new(%args);
   return $self;
}

sub new_from_quartz {
   my ( $class, %args ) = @_;
   $args{is_quartz} = 1;
   my $self = $class->_new(%args);
   return $self;
}

sub new {
   my ( $class, %args ) = @_;
   die "expression required" unless defined $args{expression};

   my @fields = split /\s+/, $args{expression};
   if ( @fields == 5 ) {
      $args{is_quartz} = 0;
   }
   elsif ( @fields == 6 || @fields == 7 ) {
      $args{is_quartz} = 1;
   }
   else {
      die "expected 5-7 fields";
   }
   my $self = $class->_new(%args);
   return $self;
}

sub _new {
   my ( $class, %args ) = @_;
   die "expression required" unless defined $args{expression};
   my $expr = uc $args{expression};
   $expr =~ s/\s+/ /g;
   $expr =~ s/^\s+|\s+$//g;

   # alias support
   if ( $expr =~ /^(@.*)/ ) {
      my $alias = $1;
      $expr = $aliases{$alias} // $expr;
      print STDERR "DEBUG: Alias '$alias' mapped to '$expr'\n" if $ENV{Cron_DEBUG};
   }

   my @fields = split /\s+/, $expr;

   # normalize to 7-field quartz expression
   if ( $args{is_quartz} ) {
      die "expected 6-7 fields, got " . scalar(@fields) unless @fields == 6 || @fields == 7;
      push( @fields, '*' ) if @fields == 6;    # year

      # convert dow names to quartz numberical equivalent
      while ( my ( $name, $num ) = each %dow_map_quartz ) {
         $fields[5] =~ s/\b\Q$name\E\b/$num/gi;
      }

      #normalize to unix by subtracting one from dow
      $fields[5] =~ s/(?<!\/)(\b[1-7]\b)/$1-1/ge;
   }
   else {
      die "expected 5 fields, got " . scalar(@fields) unless @fields == 5;
      unshift( @fields, 0 );                   # seconds
      push( @fields, '*' );                    # year

      # convert dow names to unix numerical equivalent
      while ( my ( $name, $num ) = each %dow_map_unix ) {
         $fields[5] =~ s/\b\Q$name\E\b/$num/gi;
      }
   }

   # Convert month names to numerical equivalent
   while ( my ( $name, $num ) = each %month_map ) { $fields[4] =~ s/\b\Q$name\E\b/$num/gi; }

   # enforce dom/dow mutual exclusivity
   if ( $fields[3] ne '?' && $fields[5] eq '*' ) {
      $fields[5] = '?';
   }
   elsif ( $fields[3] eq '*' && $fields[5] ne '?' ) {
      $fields[3] = '?';
   }
   elsif ( $fields[3] ne '?' && $fields[5] ne '?' ) {
      die "dow and dom cannot both be specified\n";
   }
   elsif ( $fields[3] eq '?' && $fields[5] eq '?' ) {
      die "dow and dom cannot both be unspecified\n";
   }

   die "Invalid characters" unless join( ' ', @fields ) =~ /^[#LW\d\?\*\s\-\/,]+$/;

   my $self = bless {
      fields => \@fields,
   }, $class;

   $self->utc_offset( $args{utc_offset} ) if defined $args{utc_offset};
   $self->time_zone( $args{time_zone} ) if defined $args{time_zone};
   $self->begin( $args{begin} ) if defined $args{begin};
   $self->end( $args{end} ) if defined $args{end};
   $self->user( $args{user} ) if defined $args{user};
   $self->command( $args{command} ) if defined $args{command};
   $self->env( $args{env} ) if defined $args{env};

   $self->{root} = Cron::Toolkit::Pattern::CompositePattern->new(
      type => 'root'
   );

   $self->{matcher} = Cron::Toolkit::Matcher->new(
      tree       => $self->{root},
      utc_offset => $self->utc_offset,
      owner      => $self,
   );

   $self->{composer} = Cron::Toolkit::Composer->new;

   $self->_build_tree;
   return $self;
}

sub _build_tree {
   my $self = shift;
   my @types  = qw(second minute hour dom month dow year);
   for my $i (0 .. $#types) {
      my $node = $self->_build_node($types[$i], $self->{fields}[$i]);

      # TODO: node validation goes here, e.g. check for invalid characters, invalid ranges, and min, max thresholds
      my ($min, $max) = @{ $limits{ $types[$i] } };

      # TODO: optimization goes here, e.g. step collapse and list to range
      # NOTE: only convert a list to a range if all elements are  consecutive 

      $self->{root}->add_child($node);
   }
}

sub _build_node {
   my ($self, $field, $value) = @_;
    
    my $node;

    # leaf patterns
    my $type = $value eq '*' ? 'wildcard' 
             : $value eq '?' ? 'unspecified'
             : $value eq 'L' ? 'last'
             : $value eq 'LW' ? 'lastW'
             : $value =~ /^L-(\d+)$/ ? 'last'
             : $value =~ /^\d+$/ ? 'single'
             : $value =~ /^(\d+)#(\d+)$/ ? 'nth'
             : $value =~ /^(\d+)W$/ ? 'nearest_weekday'
             : $value =~ /^(\d+)#(\d+)$/ ? 'nth'
             : undef;

    if ($type) {
       $node = Cron::Toolkit::Pattern::LeafPattern->new( 
          type => $type, 
          value => $value, 
          field_type => $field
      );
    } 

    # composite patterns
    elsif ( $value =~ /^(\d*|\*)\/(\d+)$/ ) {
        my ( $base_str, $step ) = ( $1, $2 );
        print STDERR "DEBUG: Parsing step: base=$base_str, step=$step\n" if $ENV{Cron_DEBUG};
        my $step_node = Cron::Toolkit::Pattern::CompositePattern->new(
           type => 'step',
           value => $value, 
           field_type => $field,
        );
        my $base_node =
            $base_str eq '*'
            ? Cron::Toolkit::Pattern::LeafPattern->new( type => 'wildcard', value => '*', field_type => $field )
            : Cron::Toolkit::Pattern::LeafPattern->new( type => 'single', value => $base_str, field_type => $field );
        $step_node->add_child($base_node);
        my $step_val_node = Cron::Toolkit::Pattern::LeafPattern->new( type => 'step_value', value => $step, field_type => $field );
        $step_node->add_child($step_val_node);
        $node = $step_node;
    } elsif ( $value =~ /^(\*|\d+)-(\d+)\/(\d+)$/ ) {
        my ( $start, $end, $step ) = ( $1, $2, $3 );
        print STDERR "DEBUG: Parsing step range: start=$start, end=$end, step=$step\n" if $ENV{Cron_DEBUG};
        my $range = Cron::Toolkit::Pattern::CompositePattern->new(
           type => 'range',
           field_type => $field,
        );

        $range->add_child( Cron::Toolkit::Pattern::LeafPattern->new(
           type => 'single',
           value => $start,
           field_type => $field,
        ));

        $range->add_child( Cron::Toolkit::Pattern::LeafPattern->new(
           type => 'single', 
           value => $end,
           field_type => $field,
        ));

        my $step_node = Cron::Toolkit::Pattern::CompositePattern->new( 
           type => 'step',
           field_type => $field,
        );

        $step_node->add_child($range);
        $step_node->add_child( Cron::Toolkit::Pattern::LeafPattern->new( 
           type => 'step_value', 
           value => $step ,
           field_type => $field,
        ));
        $node = $step_node;
    } elsif ( $value =~ /^(\d+)-(\d+)$/ ) {
        my ( $start, $end ) = ( $1, $2 );
        print STDERR "DEBUG: Parsing range: start=$start, end=$end\n" if $ENV{Cron_DEBUG};
        my $range = Cron::Toolkit::Pattern::CompositePattern->new( type => 'range', field_type => $field, );
        $range->add_child( Cron::Toolkit::Pattern::LeafPattern->new( type => 'single', value => $start, field_type => $field, ) );
        $range->add_child( Cron::Toolkit::Pattern::LeafPattern->new( type => 'single', value => $end, field_type => $field, ) );
        $node = $range;
    } elsif ( $value =~ /,/ ) {
        my $list = Cron::Toolkit::Pattern::CompositePattern->new( type => 'list', field_type => $field, );
        print STDERR "DEBUG: Parsing list: elements=[" . join(',', split /,/, $field) . "]\n" if $ENV{Cron_DEBUG};
        for my $sub ( split /,/, $value ) {
            $list->add_child( $self->_build_node( $field, $sub ));
        }
        $node = $list;
    } else {
        die "Unsupported field: $value";
    }
    $node->{field_type} = $field;
    return $node;
}


sub utc_offset {
   my ( $self, $new_offset ) = @_;
   if ( @_ > 1 ) {
      if ( !defined $new_offset || $new_offset !~ /^-?\d+$/ || $new_offset < -1080 || $new_offset > 1080 ) {
         die "Invalid utc_offset '$new_offset': must be an integer between -1080 and 1080 minutes";
      }
      $self->{utc_offset} = $new_offset;
      print STDERR "DEBUG: utc_offset: set to $new_offset\n" if $ENV{Cron_DEBUG};
   }
   print STDERR "DEBUG: utc_offset: returning $self->{utc_offset}\n" if $ENV{Cron_DEBUG};
   return $self->{utc_offset};
}

sub time_zone {
   my ( $self, $new_tz ) = @_;
   if ( @_ > 1 ) {
      require DateTime::TimeZone;
      my $tz   = $new_tz;
      my $zone = eval { DateTime::TimeZone->new( name => $tz ); } or do {
         die "Invalid time_zone '$tz': must be a valid TZ identifier ($@)";
      };
      $self->{time_zone} = $tz;
      my $tm = Time::Moment->now_utc;
      $self->{utc_offset} = $zone->offset_for_datetime($tm) / 60;    # Recalc to minutes (DST-aware)
      print STDERR "DEBUG: time_zone: set to $tz (offset: $self->{utc_offset})\n" if $ENV{Cron_DEBUG};
   }
   print STDERR "DEBUG: time_zone: returning $self->{time_zone}\n" if $ENV{Cron_DEBUG};
   return $self->{time_zone};
}

sub begin_epoch {
   my ( $self, $new_begin ) = @_;
   if ( @_ > 1 ) {
      die "Invalid begin_epoch '$new_begin': must be a non-negative integer" unless defined $new_begin && $new_begin =~ /^\d+$/ && $new_begin >= 0;
      $self->{begin_epoch} = $new_begin;
   }
   return $self->{begin_epoch};
}

sub end_epoch {
   my ( $self, $new_end ) = @_;
   if ( @_ > 1 ) {
      die "Invalid end_epoch '$new_end': must be undef or a non-negative integer" unless !defined $new_end || ( $new_end =~ /^\d+$/ && $new_end >= 0 );
      $self->{end_epoch} = $new_end;
   }
   return $self->{end_epoch};
}

sub user {
   my ($self) = @_;
   return $self->{user};
}

sub command {
   my ($self) = @_;
   return $self->{command};
}

sub env {
   my ($self) = @_;
   return $self->{env};
}

sub describe {
   my ($self) = @_;
   return $self->{composer}->describe( $self->{root} );
}

sub is_match {
   my ( $self, $epoch_seconds ) = @_;
   return $self->{matcher}->match($epoch_seconds);
}

# Symmetric next() with auto-clamp defaults
sub next {
   my ( $self, $epoch_seconds ) = @_;
   $epoch_seconds //= $self->begin_epoch // time;
   die "Invalid epoch_seconds: must be a non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;

   # Clamp to begin_epoch floor if set
   $epoch_seconds = max( $epoch_seconds, $self->begin_epoch // 0 ) if defined $self->begin_epoch;

   my ( $window, $step ) = $self->_estimate_window;
   my $result = $self->{matcher}->_find_next( $epoch_seconds, $epoch_seconds + $window, $step, 1 );

   # Cap to end_epoch if set
   return undef if defined $self->end_epoch && $result && $result > $self->end_epoch;
   return $result;
}

# Symmetric previous() with auto-clamp defaults
sub previous {
   my ( $self, $epoch_seconds ) = @_;
   $epoch_seconds //= time;
   die "Invalid epoch_seconds: must be a non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;

   # Clamp to end_epoch cap if set
   $epoch_seconds = min( $epoch_seconds, $self->end_epoch // $epoch_seconds ) if defined $self->end_epoch;
   my ( $window, $step ) = $self->_estimate_window;
   my $result = $self->{matcher}->_find_next( $epoch_seconds, $epoch_seconds - $window, $step, -1 );

   # Floor to begin_epoch if set
   return undef if defined $self->begin_epoch && $result && $result < $self->begin_epoch;
   return $result;
}

# next_n with max_iter guard
use constant MAX_ITER => 10000;    # Configurable? Later.

sub next_n {
   my ( $self, $epoch_seconds, $n, $max_iter ) = @_;
   $epoch_seconds //= time;
   $n             //= 1;
   $max_iter      //= MAX_ITER;
   die "Invalid epoch_seconds: must be a non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;
   die "Invalid n: must be positive integer"                   unless defined $n             && $n             =~ /^\d+$/ && $n > 0;
   die "Invalid max_iter: must be positive integer >= n"       unless defined $max_iter      && $max_iter      =~ /^\d+$/ && $max_iter >= $n;
   my @results;
   my $current = $epoch_seconds;
   my $iter    = 0;

   for ( 1 .. $n ) {
      $iter++;
      die "Exceeded max_iter ($max_iter) in next_n; possible infinite loop? Tighten end_epoch or reduce n." if $iter > $max_iter;
      my $next = $self->next($current);
      last unless defined $next;
      push @results, $next;
      $current = $next + 1;    # Skip self-match
   }
   return \@results;
}

# previous_n with max_iter guard
sub previous_n {
   my ( $self, $epoch_seconds, $n, $max_iter ) = @_;
   $epoch_seconds //= time;
   $n             //= 1;
   $max_iter      //= MAX_ITER;
   die "Invalid epoch_seconds: must be a non-negative integer" unless defined $epoch_seconds && $epoch_seconds =~ /^\d+$/ && $epoch_seconds >= 0;
   die "Invalid n: must be positive integer"                   unless defined $n             && $n             =~ /^\d+$/ && $n > 0;
   die "Invalid max_iter: must be positive integer >= n"       unless defined $max_iter      && $max_iter      =~ /^\d+$/ && $max_iter >= $n;
   my @results;
   my $current = $epoch_seconds;
   my $iter    = 0;

   while ( @results < $n ) {
      $iter++;
      die "Exceeded max_iter ($max_iter) in previous_n; possible infinite loop? Tighten begin_epoch or reduce n." if $iter > $max_iter;
      my $prev = $self->previous($current);
      last unless defined $prev;
      unshift @results, $prev;    # Oldest first (ascending)
      $current = $prev - 1;       # Advance backward
   }
   return \@results;
}

sub next_occurrences {
   my $self = shift;
   return $self->next_n(@_);
}

sub as_unix_string {
   my $self = shift;
   my $expr = $self->_as_string;
   my @fields = split(/\s+/, $expr);
   shift @fields; # remove seconds
   pop @fields; # remove year
   return join(' ', @fields);
}

sub as_quartz_string {
   my $self = shift;
   my $expr = $self->_as_string;
   my @fields = split(/\s+/, $expr);

   # add one to dow
   $fields[5] =~ s/(?<!\/)(\b[0-6]\b)/$1+1/ge;
   return join(' ', @fields);
}

sub as_string {
   my $self = shift;
   return $self->_as_string;
}

sub _as_string {
   my $self = shift;
   return $self->_rebuild_from_node($self->{root});
}

sub to_json {
   my $self = shift;
   return JSON::PP::encode_json(
      {
         expression  => $self->_as_string,
         description => $self->describe,
         utc_offset  => $self->utc_offset,
         time_zone   => $self->time_zone,
         begin_epoch => $self->begin_epoch,
         end_epoch   => $self->end_epoch,
      }
   );
}

# new_from_crontab class method
sub new_from_crontab {
   my ( $class, $content ) = @_;
   die "crontab content required (string)" unless defined $content && length $content;
   my @crons;
   my %env;
   foreach my $line ( split /\n/, $content ) {

      # Strip trailing comments and trim
      $line             =~ s/\s*#.*$//;       # Remove comments from end
      $line             =~ s/^\s+|\s+$//g;    # Trim whitespace
      next unless $line =~ /\S/;              # Skip empty
                                              # Env var: KEY=VALUE (simple; no quotes handled yet)
      if ( $line =~ /^([A-Z_][A-Z0-9_]*)=(.*)$/ ) {
         $env{$1} = $2;
         next;
      }

      # Split into tokens (simple space split; preserves quoted if manual, but for robustness, assume no embedded quotes in fields)
      my @parts = split /\s+/, $line;

      # Iterative token consumption for cron prefix
      my @cron_parts;
      my $is_alias = 0;
      for my $part (@parts) {
         last if @cron_parts >= 7;    # Cap at max Quartz fields
         if ( @cron_parts == 0 && $part =~ /^@/ ) {

            # Alias as single token
            push @cron_parts, $part;
            $is_alias = 1;
            last;                     # Aliases are single
         }
         elsif ( $part =~ /^[0-9*?,\/\-L#W?]+$/ ) {    # Cron-like: digits, *, ?, -, /, ,, L, W, #
            push @cron_parts, $part;
         }
         else {
            last;                                      # Non-cron token
         }
      }

      # Validate expression length
      my $expr = join ' ', @cron_parts;
      next unless $is_alias || ( @cron_parts >= 5 && @cron_parts <= 7 );

      # Extract user: Next token after prefix, if simple word (alphanumeric, no / or special)
      my ( $user, $command ) = ( undef, undef );
      my $cron_end   = @cron_parts;
      my $next_start = $cron_end;
      if ( @parts > $cron_end ) {
         my $potential_user = $parts[$cron_end];
         if ( $potential_user =~ /^\w+$/ ) {    # Simple username: letters/digits/_
            $user       = $potential_user;
            $next_start = $cron_end + 1;
         }
      }

      # Command: Remainder (join from next_start, preserving original spacing if needed; here simple join)
      $command = join ' ', @parts[ $next_start .. $#parts ] if @parts > $next_start;

      # Create object (new() auto-handles Unix/Quartz/aliases)
      eval {
         my $cron = $class->new(
            expression => $expr,
            user       => $user,
            command    => $command,
            env        => {%env}      # Copy current env
         );
         push @crons, $cron;
      };
      warn "Skipped invalid crontab line: '$line' ($@)" if $@;
   }
   return @crons;
}

sub _estimate_window {
   my $self = shift;
   my @fields = @{ $self->{fields} };

   # Dom constrained or DOW special: 2-month window, daily step (covers cross-month, intra-month)
   if ( $fields[3] ne '*' || $fields[5] =~ /^(L|LW|\d+W|\d+#\d+)$/ ) {
      return ( 62 * 24 * 3600, 24 * 3600 );
   }

   # Year or month constrained (no dom/DOW special): yearly window, monthly step
   if ( $fields[4] ne '*' || $fields[6] ne '*' ) {
      return ( 365 * 24 * 3600, 30 * 24 * 3600 );
   }

   # Second or minute steps: daily window, second step
   if ( $fields[0] =~ /\/\d+/ || $fields[1] =~ /\/\d+/ ) {
      return ( 24 * 3600, 1 );
   }

   # Every-second schedules: immediate window, second step
   if ( $fields[0] eq '*' && $fields[1] eq '*' && $fields[2] eq '*' && $fields[3] eq '*' && $fields[4] eq '*' && $fields[5] eq '?' && $fields[6] eq '*' ) {
      return ( 1, 1 );
   }

   # New: Year step (e.g., */4 for leaps)
   if ( $fields[6] =~ /\/\d+/ ) {
      return ( 4 * 365 * 24 * 3600, 365 * 24 * 3600 );
   }

   # Default: monthly window, daily step
   return ( 31 * 24 * 3600, 24 * 3600 );
}

sub dump_tree {
   my ( $self_or_node, $indent ) = @_;
   $indent //= 0;
   if ( ref($self_or_node) eq 'Cron::Toolkit' ) {
      my $self = $self_or_node;
      #say "Cron::Toolkit (user: " . ( $self->user // 'undef' ) . ", command: " . ( $self->command // 'undef' ) . ")";
      $self_or_node = $self->{root};
   }
   return unless $self_or_node;
   my $prefix = ' ' x $indent;
   my $type   = $self_or_node->{type} // 'root';
   my $val    = $self_or_node->{value}      ? " ($self_or_node->{value})"      : '';
   my $field  = $self_or_node->{field_type} ? " [$self_or_node->{field_type}]" : '';
   say $prefix . ucfirst($type) . $val . $field;

   # Recurse children
   for my $child ( @{ $self_or_node->{children} || [] } ) {
      $child->dump_tree( $indent + 2 );
   }
}

sub _rebuild_from_node {
    my ($self, $node) = @_;
    my $type = $node->{type};
    return '*' if $type eq 'wildcard';
    return '?' if $type eq 'unspecified';
    return $node->{value} if $type eq 'single' || $type eq 'last' || $type eq 'lastW' || $type eq 'nth' || $type eq 'nearest_weekday' || $type eq 'step_value';
    return $self->_rebuild_from_node($node->{children}[0]) . '-' . $self->_rebuild_from_node($node->{children}[1]) if $type eq 'range';
    return $self->_rebuild_from_node($node->{children}[0]) . '/' . $self->_rebuild_from_node($node->{children}[1]) if $type eq 'step';
    return join ',', map { $self->_rebuild_from_node($_) } @{ $node->{children} } if $type eq 'list';
    return join ' ', map { $self->_rebuild_from_node($_) } @{ $node->{children} } if $type eq 'root';
    die "Unsupported for rebuild: $type";
}

1;
__END__
