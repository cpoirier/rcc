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
 # class BacktrackingActivated
 #  - explanation that indicates a series of actions will be attempted
 #  - only used if backtracking is enabled

   class BacktrackingActivated < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( actions )
         @actions = actions
      end
      
      
      def to_s()
         return "Backtracking activated.  Will attempt:\n   " + @actions.collect{|action| action.to_s}.join("\n   ")
      end
      
      
   end # BacktrackingActivated
   



end  # module Explanations
end  # module Plan
end  # module Rethink


