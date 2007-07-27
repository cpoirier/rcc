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

module RCC
module Plan
module Explanations

 
 #============================================================================================================================
 # class Explanation
 #  - base class for things that explain why actions where produced the way they were

   class Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( )
      end
      
      
      
   end # Explanation
   



end  # module Explanations
end  # module Plan
end  # module Rethink



require "rcc/plan/explanations/reductions_sorted.rb"
require "rcc/plan/explanations/shift_trumps_reduce.rb"
require "rcc/plan/explanations/reduce_trumps_shift.rb"

