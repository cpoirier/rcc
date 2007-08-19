#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

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


require "#{$RCCLIB}/model/terminal_definitions/simple.rb"
require "#{$RCCLIB}/model/terminal_definitions/pattern.rb"
require "#{$RCCLIB}/model/terminal_definitions/special.rb"
