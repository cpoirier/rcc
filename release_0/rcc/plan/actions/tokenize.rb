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
 # class Tokenize
 #  - a character-oriented Reduce action for the ParserPlan

   class Tokenize < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :by_production
      
      def initialize( by_production )
         @by_production = by_production
      end
      
      
      def to_s()
         return "Tokenize #{@by_production.to_s}"
      end
      
   end # Tokenize
   


end  # module Actions
end  # module Plan
end  # module RCC
