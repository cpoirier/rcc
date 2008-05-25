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
require "#{$RCCLIB}/plan/actions/action.rb"

module RCC
module Plan
module Actions

 
 #============================================================================================================================
 # class Read
 #  - a character-oriented Shift action for the ParserPlan

   class Read < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :character_range
      attr_reader :to_state
      
      def initialize( character_range, to_state )
         @character_range     = character_range
         @to_state            = to_state
      end
      
      def to_s()
         return "Read #{@character_range}, then goto #{@to_state.number}"
      end
      
   end # Read
   


end  # module Actions
end  # module Plan
end  # module RCC
