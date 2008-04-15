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
 # class Shift
 #  - a Shift action for the ParserPlan

   class Shift < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :to_state
      attr_reader :valid_productions
      
      def initialize( symbol_name, to_state, valid_productions, disambiguates_parse )
         @symbol_name         = symbol_name
         @to_state            = to_state
         @valid_productions   = valid_productions
         @disambiguates_parse = disambiguates_parse
      end
      
      def valid_production?( production )
         return @valid_productions.member?(production)
      end
      
      def disambiguates_parse?()
         return @disambiguates_parse
      end
      
      def to_s()
         return "Shift #{@symbol_name.description}, then goto #{@to_state.number}"
      end
      
   end # Shift
   


end  # module Actions
end  # module Plan
end  # module RCC
