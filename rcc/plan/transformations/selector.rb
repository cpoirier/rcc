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

      
      def initialize( target )
         @target = target
      end
      
      def target?()
         return @target
      end
      
      
      #
      # apply()
      
      def apply( nodes )
         bug( "you must override Selector.apply()" )
      end
      
      
      #
      # collect()
      #  - applies this Selector to a set of nodes and returns the results
      
      def collect()
         bug( "you must override Selector.process()" )
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << " (target)" if @target
      end
      
      
   end # Selector
   


end  # module Transformations
end  # module Plan
end  # module RCC


require "#{$RCCLIB}/plan/transformations/selector_sequence.rb"
require "#{$RCCLIB}/plan/transformations/selector_branch.rb"

require "#{$RCCLIB}/plan/transformations/self_selector.rb"
require "#{$RCCLIB}/plan/transformations/slot_selector.rb"
require "#{$RCCLIB}/plan/transformations/transitive_closure.rb"
require "#{$RCCLIB}/plan/transformations/predicate.rb"
