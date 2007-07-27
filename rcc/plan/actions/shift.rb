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
 # class Shift
 #  - a Shift action for the ParserPlan

   class Shift < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :to_state
      
      def initialize( symbol_name, to_state )
         @symbol_name = symbol_name
         @to_state    = to_state
      end
      
      def to_s()
         return "Shift #{Plan::Symbol.describe(@symbol_name)}, then goto #{@to_state.state_number}"
      end
      
   end # Shift
   


end  # module Actions
end  # module Plan
end  # module Rethink
