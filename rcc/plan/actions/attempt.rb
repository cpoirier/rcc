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
 # class Attempt
 #  - a Action that allows a set of Actions to be attempted, in sequence, until one of them succeeds

   class Attempt
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( actions )
         @actions = actions
      end
      
   end # Attempt
   


end  # module Actions
end  # module Plan
end  # module Rethink
