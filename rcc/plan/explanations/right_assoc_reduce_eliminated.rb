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
 # class RightAssocReduceEliminated
 #  - explanation that indicates a shift action was chosen over a reduce action for associativity reasons

   class RightAssocReduceEliminated < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( shift, reduction )
         @shift     = shift
         @reduction = reduction
      end
      
      
      def to_s()
         return "Shift [ #{@shift.to_s}] eliminates Reduce [ #{@reduction.to_s}]; equal precedence, reduce is right-associative"
      end
      
      
   end # RightAssocReduceEliminated
   



end  # module Explanations
end  # module Plan
end  # module RCC


