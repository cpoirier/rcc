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
 # class ReductionsSorted
 #  - an explanation indicating the sort order for reductions

   class ReductionsSorted < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( items )
         @items = items
      end
      
      def to_s()
         return "Sorted reductions into declaration order: #{@items.collect{|item| item.to_s()}.join("; ")}"
      end
      
      
   end # ReductionsSorted
   



end  # module Explanations
end  # module Plan
end  # module Rethink
