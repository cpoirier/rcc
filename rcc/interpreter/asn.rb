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
require "rcc/util/ordered_hash.rb"

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
      
      def initialize( production, component_symbols )
         @root_symbol = production.name
         @ast_class   = production.ast_class
         @slots       = Util::OrderedHash.new()
         
         production.slot_mappings.each do |index, slot|
            @slots[slot] = component_symbols[index]
         end
      end
      
      
      def description()
         return "#{@root_symbol}"
      end
      
      
      def display( stream, indent = "" )
         stream << indent << "#{@ast_class.name} < #{@ast_class.parent_name} =>" << "\n"
         
         indent1 = indent + "   "
         indent2 = indent1 + "   "
         @slots.each do |slot_name, symbol|
            stream << indent1 << slot_name << ":\n"
            symbol.display( stream, indent2 )
         end
      end
      
      
   end # ASN
   


end  # module Interpreter
end  # module Rethink
