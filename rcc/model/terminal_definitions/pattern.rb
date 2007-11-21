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
require "#{$RCCLIB}/model/terminal_definitions/definition.rb"

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

      attr_reader :exemplar
      
      def initialize( definition, exemplar, name = nil )
         super( definition, name )
         @exemplar = exemplar
         @regexp   = nil
      end
      
      def regexp
         @regexp = Regexp.compile( definition.slice(1..-2), Regexp::MULTILINE ) if @regexp.nil?
         return @regexp
      end
      
      
      
   end # class Pattern
   



end  # module TerminalDefinitions
end  # module Model
end  # module RCC
