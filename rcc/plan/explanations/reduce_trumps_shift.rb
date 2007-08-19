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
 # class ReduceTrumpsShift
 #  - explanation that indicates a reduce action was chosen over a shift action for precedence or associativity reasons

   class ReduceTrumpsShift < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( reduction, shift, by_associativity = false )
         @reduction        = reduction
         @shift            = shift
         @by_associativity = by_associativity
      end
      
      
      def to_s()
         if @by_associativity then
            return "Reduce [ #{@reduction.to_s}] beats Shift [ #{@shift.to_s}]; equal precedence, left-associative"
         else
            return "Reduce [ #{@reduction.to_s}] beats Shift [ #{@shift.to_s}]; higher precedence"
         end
      end
      
      
   end # ReduceTrumpsShift
   



end  # module Explanations
end  # module Plan
end  # module Rethink


