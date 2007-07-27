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
require "rcc/plan/actions/action.rb"

module RCC
module Plan
module Actions

 
 #============================================================================================================================
 # class Accept
 #  - an Accept action for the ParserPlan

   class Accept < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( production )
         @production = production
      end
      
      
      def to_s()
         return "Accept #{@production.to_s}"
      end
      
   end # Accept
   


end  # module Actions
end  # module Plan
end  # module Rethink
