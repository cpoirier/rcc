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
require "#{$RCCLIB}/plan/transformations/selector.rb"

module RCC
module Plan
module Transformations
 
 
 #============================================================================================================================
 # class TransitiveClosure
 #  - a selector that repeatedly applies another selector to a set of nodes, merging in the results, until all results are 
 #    found

   class TransitiveClosure < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :selector
      
      def initialize( selector )
         super( false )
         @selector = selector
      end
      
      
      #
      # apply()
      #  - transitive closure always results in plural results
      #  - we assume most trees are left-associative, and so reverse the results order
      
      def apply( nodes )
         nodes      = nodes.to_a
         results    = nodes
         difference = nodes
         until difference.empty?
            step_results = @selector.apply( difference )
            difference   = step_results - results
            results.concat( difference )
         end
         
         return results.reverse
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << "{" << @selector << "}"
      end
      
      
   end # TransitiveClosure
   


end  # module Transformations
end  # module Plan
end  # module RCC
