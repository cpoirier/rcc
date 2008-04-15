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
require "#{$RCCLIB}/plan/explanations/explanation.rb"

module RCC
module Plan
module Explanations

 
 #============================================================================================================================
 # class LeftAssocReduceEliminatesShift
 #  - explanation that indicates a reduce action was chosen over a shift action for associativity reasons

   class LeftAssocReduceEliminatesShift < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( reduction, shift )
         @reduction = reduction
         @shift     = shift
      end
      
      
      def to_s()
         return "Reduce [ #{@reduction.to_s}] eliminates Shift [ #{@shift.to_s}]; equal precedence, left-associative"
      end
      
      
   end # LeftAssocReduceEliminatesShift
   



end  # module Explanations
end  # module Plan
end  # module RCC


