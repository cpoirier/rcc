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
require "#{$RCCLIB}/util/expression_forms/sequence.rb"


module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class PredicateOr
 #  - a specialized BranchPoint for holding ORd predicates

   class PredicateOr < Util::ExpressionForms::BranchPoint
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      
      #
      # apply()
      #  - for PredicateOr, we take the union of all produced nodes
      
      def apply( nodes )
         results = []
         self.each_element do |element|
            results |= element.apply( nodes )
         end
         
         return results
      end
      
      
      
      #
      # display()
      
      def display( stream = $stdout )
         show_separator = false
         self.branches.each do |element|
            stream << "|" if show_separator
            stream << "(" << element << ")"
            
            show_separator = true
         end
      end
      
      
   end # PredicateOr
   


end  # module Transformations
end  # module Plan
end  # module RCC


