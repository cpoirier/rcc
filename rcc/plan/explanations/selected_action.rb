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
 # class SelectedAction
 #  - explanation showing the final disposition for a lookahead symbol

   class SelectedAction < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( action )
         @action = action
      end
      
      
      def to_s()
         return "Selected action: #{@action.to_s}"
      end
      
      
      
   end # OnlyOneChoice
   



end  # module Explanations
end  # module Plan
end  # module Rethink

