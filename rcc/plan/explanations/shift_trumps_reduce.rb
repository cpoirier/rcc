#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"
require "rcc/plan/explanations/explanation.rb"

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

      def initialize( shift, reduction )
         @shift     = shift
         @reduction = reduction
      end
      
      
      
   end # ShiftTrumpsReduce
   



end  # module Explanations
end  # module Plan
end  # module Rethink


