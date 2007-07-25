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
module Model
module TerminalDefinitions

 
 #============================================================================================================================
 # class Definition
 #  - base class for the lexical object definitions

   class Definition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :definition
      attr_reader :name
      
      def initialize( definition, name = nil )
         @definition = definition
         @name       = name
      end
      
      
      
      
   end # Definition
   



end  # module TerminalDefinitions
end  # module Model
end  # module Rethink


require "rcc/model/terminal_definitions/simple.rb"
require "rcc/model/terminal_definitions/pattern.rb"
require "rcc/model/terminal_definitions/special.rb"
