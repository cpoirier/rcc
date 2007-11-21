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
 # class OnlyOneChoice
 #  - base class for things that explain why actions where produced the way they were

   class OnlyOneChoice < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( item )
         @item = item
      end
      
      
      def to_s()
         return "Only option: #{@item.to_s}"
      end
      
      
   end # OnlyOneChoice
   



end  # module Explanations
end  # module Plan
end  # module RCC

