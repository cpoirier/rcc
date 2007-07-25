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
 # class Reduce
 #  - a Reduce action for the ParserPlan

   class Reduce
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( by_rule )
         @by_rule = by_rule
      end
      
   end # Reduce
   


end  # module Actions
end  # module Plan
end  # module Rethink
