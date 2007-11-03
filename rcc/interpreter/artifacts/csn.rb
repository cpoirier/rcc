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
require "#{$RCCLIB}/interpreter/artifacts/node.rb"

module RCC
module Interpreter
module Artifacts
   

 
 #============================================================================================================================
 # class CSN
 #  - a Node in a Concrete Syntax Tree produced by the Interpreter

   class CSN < Node
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :component_symbols   # The Symbols that comprise it
      
      def initialize( root_symbol, component_symbols )
         super( root_symbol, component_symbols )
         @component_symbols = component_symbols
      end
      
      def first_token
         return @component_symbols[0].first_token
      end
      
      def last_token
         return @component_symbols[-1].last_token
      end
      
      def display( stream, indent = "" )
         stream << indent << "#{@root_symbol} =>" << "\n"
         
         child_indent = indent + "   "
         @component_symbols.each do |symbol|
            symbol.display( stream, child_indent )
         end
      end
      

      
   end # CSN
   


end  # module Artifacts
end  # module Interpreter
end  # module Rethink
