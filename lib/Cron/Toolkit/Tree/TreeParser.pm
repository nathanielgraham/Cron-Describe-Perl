package Cron::Toolkit::Tree::TreeParser;
use strict;
use warnings;
use Cron::Toolkit::Tree::CompositePattern;
use Cron::Toolkit::Tree::LeafPattern;
use Cron::Toolkit::Tree::Utils qw(validate %limits);
use Carp                       qw(croak);

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
      my ( $base_str, $step ) = ( $1, $2 );
      my ( $min,      $max )  = @{ $limits{$field_type} };

      #$step = 0 + $step;
      my $effective_start = ( $base_str eq '*' ) ? $min : ( 0 + ( $base_str // $min ) );

      # Adjust min for DOM/month steps (start from 1 even if *)
      $effective_start = $min if $field_type =~ /^(dom|month)$/ && $effective_start < $min;

      # Collapse degenerate
      if ( $effective_start + $step > $max ) {
         my $node = Cron::Toolkit::Tree::LeafPattern->new( type => 'single', value => $effective_start );
         return $node;
      }

      # Non-degenerate: Build step node
      my $step_node = Cron::Toolkit::Tree::CompositePattern->new( type => 'step' );
      my $base_node =
        $base_str eq '*'
        ? Cron::Toolkit::Tree::LeafPattern->new( type => 'wildcard', value => '*' )
        : Cron::Toolkit::Tree::LeafPattern->new( type => 'single',   value => $base_str );
      $step_node->add_child($base_node);
      my $step_val_node = Cron::Toolkit::Tree::LeafPattern->new( type => 'step_value', value => $step );
      $step_node->add_child($step_val_node);
      return $step_node;
   }

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
