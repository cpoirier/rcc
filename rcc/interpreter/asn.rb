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
module Interpreter

 
 #============================================================================================================================
 # class ASN
 #  - a Node in an Abstract Syntax Tree produced by the Interpreter

   class ASN
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :root_symbol    # The Symbol this CSN represents
      attr_reader :slots          # The named Symbols that comprise it
      
      alias :symbol :root_symbol
      
      def initialize( production, root_symbol, component_symbols )
         @root_symbol = root_symbol
         @ast_class   = production.ast_class
         @slots       = {}
         
         production.slot_mappings.each do |index, slot|
            @slots[slot] = component_symbols[index]
         end
      end
      
      
      def description()
         return "#{@root_symbol}"
      end
      
      
      def display( stream, indent = "" )
         stream << indent << "#{@root_symbol} =>" << "\n"
         
         child_indent = indent + "   "
         @component_symbols.each do |symbol|
            symbol.display( stream, child_indent )
         end
      end
      
      
   end # CSN
   


end  # module Interpreter
end  # module Rethink
