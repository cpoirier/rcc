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
 # class Pattern
 #  - a terminal described by a regex pattern

   class Pattern < Definition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( definition, name = nil )
         super( definition, name )
         @regexp = nil
      end
      
      def regexp
         @regexp = Regexp.compile( definition.slice(1..-2), Regexp::MULTILINE ) if @regexp.nil?
         return @regexp
      end
      
      
   end # class Pattern
   



end  # module TerminalDefinitions
end  # module Model
end  # module Rethink
