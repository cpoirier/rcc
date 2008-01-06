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
end  # module RCC

