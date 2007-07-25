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
module Actions

 
 #============================================================================================================================
 # class Shift
 #  - a Shift action for the ParserPlan

   class Shift
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( to_state )
         @to_state = to_state
      end
      
   end # Shift
   


end  # module Actions
end  # module Plan
end  # module Rethink
