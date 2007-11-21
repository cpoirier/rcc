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
 # class FavouriteChosen
 #  - explanation that indicates a shift was chosen over a reduce or an earlier reduce over another reduce
 #  - only used if backtracking is disabled

   class FavouriteChosen < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( actions )
         @actions = actions
      end
      
      
      def to_s()
         if @actions[0].is_a?(Actions::Shift) then
            return "Shift beats Reduce in general shift/reduce conflicts"
         else
            return "Earliest stated rule wins in reduce/reduce conflicts"
         end
      end
      
      
   end # FavouriteChosen
   



end  # module Explanations
end  # module Plan
end  # module RCC


