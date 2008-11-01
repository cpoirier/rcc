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
 # class LeftAssocReduceEliminated
 #  - explanation that indicates a shift action was chosen over a reduce action for associativity reasons

   class LeftAssocReduceEliminated < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( reduction, shifts )
         @reduction = reduction
         @shifts    = shifts
      end
      
      
      def to_s()
         return "High-priority shifts [#{@shifts.join("], [")}] eliminate unrelated, lower-priority, left-associativeReduce [#{@reduction.to_s}]"
      end
      
      
   end # LeftAssocReduceEliminated
   



end  # module Explanations
end  # module Plan
end  # module RCC


