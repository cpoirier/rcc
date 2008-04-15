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
 # class ItemsDoNotMeetThreshold
 #  - an explanation indicating those items that fell below the priority threshold for the set

   class ItemsDoNotMeetThreshold < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( items )
         @items = items
      end
      
      def to_s()
         return "Items that do not meet the priority threshold for this state: #{@items.collect{|item| item.to_s()}.join("; ")}"
      end
      
      
   end # ItemsDoNotMeetThreshold
   



end  # module Explanations
end  # module Plan
end  # module RCC
