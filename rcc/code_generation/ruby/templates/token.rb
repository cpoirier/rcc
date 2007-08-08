#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================



%%MODULE_HEADER%%
 

 #============================================================================================================================
 # class Token
 #  - a String that contains source information about the file it was read from 
 #  - produced by the Lexer

   class Token < String
      
      attr_reader   :line_number          # The line number within the source this token came from
      attr_reader   :column_number        # The column on which this token starts (if known)
      attr_reader   :source_descriptor    # Some string that describes the source of this token
      
      def locate( position, line_number, column_number, source_descriptor, type = nil, raw_text = nil )
         @position          = position
         @line_number       = line_number
         @column_number     = column_number
         @source_descriptor = source_descriptor
         @type              = type
         @raw_text          = nil
      end
      
      def type()
         return (@type.nil? ? self : @type)
      end
      
      def raw_text()
         return (@raw_text.nil? ? self : @raw_text)
      end
      
      
      #
      # ::build()
      #  - builds a new, fully located Token from parts
      
      def self.build( text, position, line_number, column_number, source_descriptor, type = nil, raw_text = nil )
         token = new( text )
         token.locate( position, line_number, column_number, source_descriptor, type, raw_text )
         return token
      end

   end # Token
 


   

%%MODULE_FOOTER%%
