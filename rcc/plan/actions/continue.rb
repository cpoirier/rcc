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
 # class Continue
 #  - a group-oriented Shift action for the ParserPlan

   class Continue < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :to_state
      
      def initialize( group_name, to_state )
         @group_name = group_name
         @to_state   = to_state
      end
      
      def to_s()
         return "Shift #{@group_name}, then goto #{@to_state.number}"
      end
      
   end # Continue
   


end  # module Actions
end  # module Plan
end  # module RCC
