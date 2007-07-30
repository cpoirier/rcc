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
require "rcc/model/terminal_definitions/definition.rb"

module RCC
module Model
module TerminalDefinitions

 
 #============================================================================================================================
 # class Special
 #  - a terminal described by a special built-in processor (ie. identifier, number, integer, etc.)

   class Special < Definition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( definition, name = nil )
         super( definition, name )
      end
      
      
      
      
   end # class Special
   



end  # module TerminalDefinitions
end  # module Model
end  # module Rethink