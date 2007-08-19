#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/plan/explanations/explanation.rb"

module RCC
module Plan
module Explanations

 
 #============================================================================================================================
 # class ShiftTrumpsReduce
 #  - explanation that indicates a shift action was chosen over a reduce action for precedence or associativity reasons

   class ShiftTrumpsReduce < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( shift, reduction, by_associativity = false )
         @shift            = shift
         @reduction        = reduction
         @by_associativity = by_associativity
      end
      
      
      def to_s()
         if @by_associativity then
            return "Shift [ #{@shift.to_s}] beats Reduce [ #{@reduction.to_s}]; equal precedence, right-associative"
         else
            return "Shift [ #{@shift.to_s}] beats Reduce [ #{@reduction.to_s}]; higher precedence"
         end
      end
      
      
   end # ShiftTrumpsReduce
   



end  # module Explanations
end  # module Plan
end  # module Rethink


