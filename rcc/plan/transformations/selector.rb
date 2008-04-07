#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class Selector
 #  - a base class for things that select nodes from an ASN as part of a transformation

   class Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_accessor :target_predicate
      
      def initialize( target )
         @target = target
      end
      
      def target?()
         return @target
      end
      
      def has_target_predicate?()
         return (defined?(@target_predicate) and @target_predicate.exists?)
      end
      
      
      #
      # apply()
      #  - applies this selector to a node set, returning the resulting node(s)
      #  - always returns a list in a plural context 
      
      def apply( node )
         bug( "you must override Selector.apply()" )
      end
      
      
      #
      # assign()
      #  - most selectors can't be assigned to, but can form the path to the target
      
      def assign( search_nodes, result_nodes )
         return apply(search_nodes)
      end
      
      
      #
      # append()
      #  - most selectors can't be append to, but can form the path to the target
      
      def append( search_nodes, result_nodes )
         return apply(search_nodes)
      end

      
      #
      # targets()
      #  - used to collect targets for LHS selectors
      
      def targets()
         if @target then
            return [self]
         else
            return []
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         if target? then
            stream << " (target)"
            stream << " if " << @target_predicate if has_target_predicate?
         end
      end
      
      
   end # Selector
   


end  # module Transformations
end  # module Plan
end  # module RCC


require "#{$RCCLIB}/plan/transformations/selector_sequence.rb"
require "#{$RCCLIB}/plan/transformations/selector_branch.rb"

require "#{$RCCLIB}/plan/transformations/self_selector.rb"
require "#{$RCCLIB}/plan/transformations/slot_selector.rb"
require "#{$RCCLIB}/plan/transformations/reverse_selector.rb"
require "#{$RCCLIB}/plan/transformations/transitive_closure.rb"
require "#{$RCCLIB}/plan/transformations/predicate.rb"
