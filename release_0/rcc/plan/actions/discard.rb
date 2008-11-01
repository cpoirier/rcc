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
 # class Discard
 #  - a Discard action for the ParserPlan

   class Discard < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :to_state
      
      def initialize( symbol_name, to_state = nil )
         @symbol_name = symbol_name
         @to_state    = to_state
      end
      
      def to_s()
         if @to_state.nil? then
            return "Discard #{@symbol_name.description}, then resume"
         else
            return "Discard #{@symbol_name.description}, then goto #{@to_state.number}"
         end
      end
      
   end # Discard
   


end  # module Actions
end  # module Plan
end  # module RCC
