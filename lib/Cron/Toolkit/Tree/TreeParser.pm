package Cron::Toolkit::Tree::TreeParser;
use strict;
use warnings;
use Cron::Toolkit::Tree::CompositePattern;
use Cron::Toolkit::Tree::LeafPattern;
use Cron::Toolkit::Tree::Utils qw(validate %limits);
use Carp qw(croak);

sub parse_field {
   my ( $class, $field, $field_type ) = @_;
   return unless defined $field && $field ne '';
   validate( $field, $field_type );

   if ( $field eq '*' ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'wildcard', value => '*' );
   }
   elsif ( $field eq '?' ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'unspecified', value => '?' );
   }
   elsif ( $field =~ /^L$/ ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'last', value => 'L' );
   }
   elsif ( $field =~ /^L-(\d+)$/ ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'last', value => "L-$1" );
   }
   elsif ( $field =~ /^LW$/ ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'lastW', value => 'LW' );
   }
   elsif ( $field =~ /^\d+$/ ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $field );
   }
   elsif ( $field =~ /^(\d+)#(\d+)$/ ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'nth', value => $field );
   }
   elsif ( $field =~ /^(\d+)W$/ ) {
      return Cron::Toolkit::Tree::LeafPattern->new( type => 'nearest_weekday', value => $field );
   }

elsif ( $field =~ /^(\d*|\*)\/(\d+)$/ ) {
   my ($base_str, $step) = ($1, $2);
   my ($min, $max) = @{ $limits{$field_type} };
   #$step = 0 + $step;
   my $effective_start = ($base_str eq '*') ? $min : (0 + ($base_str // $min));
   # Adjust min for DOM/month steps (start from 1 even if *)
   $effective_start = $min if $field_type =~ /^(dom|month)$/ && $effective_start < $min;
   print STDERR "STEP DEBUG: field='$field', type='$field_type', base_str='$base_str', step=$step, effective=$effective_start, min=$min, max=$max, sum=" . ($effective_start + $step) . " >max? " . (($effective_start + $step > $max) ? 'yes' : 'no') . "\n" if $ENV{Cron_DEBUG};
   # Collapse degenerate
   if ($effective_start + $step > $max) {
      my $node = Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $effective_start );
      print STDERR "STEP DEBUG: Collapsed to single ref=" . ref($node) . "\n" if $ENV{Cron_DEBUG};
      return $node;
   }
   # Non-degenerate: Build step node
   my $step_node = Cron::Toolkit::Tree::CompositePattern->new( type => 'step' );
   my $base_node = $base_str eq '*'
      ? Cron::Toolkit::Tree::LeafPattern->new( type => 'wildcard', value => '*' )
      : Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $base_str );
   print STDERR "STEP DEBUG: base_node ref=" . ref($base_node) . "\n" if $ENV{Cron_DEBUG};
   $step_node->add_child( $base_node );
   my $step_val_node = Cron::Toolkit::Tree::LeafPattern->new( type => 'step_value', value => $step );
   print STDERR "STEP DEBUG: step_val_node ref=" . ref($step_val_node) . "\n" if $ENV{Cron_DEBUG};
   $step_node->add_child( $step_val_node );
   return $step_node;
}

=pod
elsif ( $field =~ /^(\d*|\*)\/(\d+)$/ ) {
   my ($base_str, $step) = ($1, $2);
   my ($min, $max) = @{ $limits{$field_type} };
   my $effective_start = ($base_str eq '*') ? $min : $base_str // $min;
   if ($field_type =~ /^(dom|month)$/ && $effective_start < $min) { $effective_start = $min; }
   warn "Step collapse check: field_type=$field_type, base='$base_str', step=$step, start=$effective_start, max=$max, sum=" . ($effective_start + $step) . "\n" if $ENV{Cron_DEBUG};
   if ($effective_start + $step > $max) {
      my $node = Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $effective_start );
      warn "Collapsed to single ref: " . ref($node) . "\n" if $ENV{Cron_DEBUG};
      return $node;
   }
   # Non-degen build...
   my $step_node = Cron::Toolkit::Tree::CompositePattern->new( type => 'step' );
   my $base_node = $base_str eq '*'
      ? Cron::Toolkit::Tree::LeafPattern->new( type => 'wildcard', value => '*' )
      : Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $base_str );
   warn "Base node ref: " . ref($base_node) . "\n" if $ENV{Cron_DEBUG};
   $step_node->add_child( $base_node );
   my $step_val_node = Cron::Toolkit::Tree::LeafPattern->new( type => 'step_value', value => $step );
   warn "Step_value node ref: " . ref($step_val_node) . "\n" if $ENV{Cron_DEBUG};
   $step_node->add_child( $step_val_node );
   return $step_node;
}

   elsif ( $field =~ /^(\d*|\*)\/(\d+)$/ ) {
      my ($base_str, $step) = ($1, $2);
      my ($min, $max) = @{ $limits{$field_type} };

      # Effective start: * → min (0 or 1 for DOM/month), else parse digits
      my $effective_start = ($base_str eq '*') ? $min : $base_str;
      $effective_start //= $min;  # Fallback if empty digits (edge, but safe)

      # Adjust min for DOM/month steps (start from 1 even if *)
      $effective_start = $min if $field_type =~ /^(dom|month)$/ && $effective_start < $min;

      # Collapse degenerate: if effective_start + step > max, sequence = [effective_start]
      if ($effective_start + $step > $max) {
         return Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $effective_start );
      }

      # Non-degenerate: Build step node
      my $step_node = Cron::Toolkit::Tree::CompositePattern->new( type => 'step' );
      $step_node->add_child(
         $base_str eq '*'
         ? Cron::Toolkit::Tree::LeafPattern->new( type => 'wildcard', value => '*' )
         : Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $base_str )
      );
      $step_node->add_child( Cron::Toolkit::Tree::LeafPattern->new( type => 'step_value', value => $step ) );
      return $step_node;
   }
=cut
#
   elsif ( $field =~ /^(\*|\d+)-(\d+)\/(\d+)$/ ) {
      my $range = Cron::Toolkit::Tree::CompositePattern->new( type => 'range' );
      $range->add_child( Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $1 ) );
      $range->add_child( Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $2 ) );
      my $step = Cron::Toolkit::Tree::CompositePattern->new( type => 'step' );
      $step->add_child($range);
      $step->add_child( Cron::Toolkit::Tree::LeafPattern->new( type => 'step_value', value => $3 ) );
      return $step;
   }
   elsif ( $field =~ /^(\d+)-(\d+)$/ ) {
      my $range = Cron::Toolkit::Tree::CompositePattern->new( type => 'range' );
      $range->add_child( Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $1 ) );
      $range->add_child( Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $2 ) );
      return $range;
   }
   elsif ( $field =~ /,/ ) {
      my $list = Cron::Toolkit::Tree::CompositePattern->new( type => 'list' );
      for my $sub ( split /,/, $field ) {
         $list->add_child( $class->parse_field( $sub, $field_type ) );
      }
      return $list;
   }
   croak "Unsupported field: $field ($field_type)";
}

1;
