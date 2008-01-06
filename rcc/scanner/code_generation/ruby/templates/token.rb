#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================


require "#{File.dirname(File.expand_path(__FILE__))}/node.rb" 



%%MODULE_HEADER%%
 

 #============================================================================================================================
 # class Token
 #  - a Lexer-produced Node that contains a String from the source, plus information about its type and source location

   class Token < Node

      attr_reader :text                 # The text of this Token
      attr_reader :line_number          # The line number within the source this token came from
      attr_reader :column_number        # The column on which this token starts (if known)
      attr_reader :source_descriptor    # Some string that describes the source of this token
      
      def initialize( text, type, position, line_number, column_number, source_descriptor, value = nil )
         super( type.nil? ? text : type, value )
         
         @position          = position
         @line_number       = line_number
         @column_number     = column_number
         @source_descriptor = source_descriptor
      end
      
   end # Token
 


   

%%MODULE_FOOTER%%
