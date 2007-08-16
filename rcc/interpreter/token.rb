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
      
      attr_reader :start_position
      attr_writer :faked
      
      def locate( start_position, line_number, column_number, source_descriptor, type = nil, raw_text = nil )
         @start_position = start_position
         @faked          = false
         super( line_number, column_number, source_descriptor, type, raw_text )
      end
      
      
      def faked?()
         return @faked
      end
      
      
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
