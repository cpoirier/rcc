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
 # class ReduceTrumpsShift
 #  - explanation that indicates a reduce action was chosen over a shift action for precedence or associativity reasons

   class ReduceTrumpsShift < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( reduction, shift )
         @reduction = reduction
         @shift     = shift
      end
      
      
      
   end # ReduceTrumpsShift
   



end  # module Explanations
end  # module Plan
end  # module Rethink


