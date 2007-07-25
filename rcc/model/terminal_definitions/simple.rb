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
 # class Simple
 #  - a terminal described by a string

   class Simple < Definition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( definition, name = nil )
         super( definition, name )
      end
      
      
      
      
   end # class Simple
   



end  # module TerminalDefinitions
end  # module Model
end  # module Rethink
