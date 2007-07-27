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
 # class Reduce
 #  - a Reduce action for the ParserPlan

   class Reduce < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :by_production
      
      def initialize( by_production )
         @by_production = by_production
      end
      
      
      def to_s()
         return "Reduce #{@by_production.to_s}"
      end
      
   end # Reduce
   


end  # module Actions
end  # module Plan
end  # module Rethink
