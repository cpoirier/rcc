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
require "rcc/model/token.rb"

module RCC
module Interpreter

 
 #============================================================================================================================
 # class Token
 #  - a Token produced at runtime from a source file

   class Token < Model::Token
      
      #
      # matches_terminal?()
      #  - returns true if this Token matches the specified Terminal
      
      def matches_terminal?( terminal )
         return (@type == terminal.type and @text == terminal.text)
      end
      
      
      #
      # description()
      
      def description( include_location = false )
         nyi "include_location" if include_location
         "[#{self.gsub("\n", "\\n")}]" + (@type.is_a?(Symbol) ? ":#{@type}" : "")
      end
      
      
      def display( stream, indent = "" )
         stream << indent << description << "\n"
      end
      
      
      
   end # Token
   


end  # module Interpreter
end  # module Rethink
