#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Model

 
 #============================================================================================================================
 # class Token
 #  - a String that contains source information about the file it was read from 
 #  - produced by the Grammar Loader's lexer

   class Token < String
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader   :line_number          # The line number within the source this token came from
      attr_reader   :column_number        # The column on which this token starts (if known)
      attr_reader   :source_descriptor    # Some string that describes the source of this token
      
      def locate( line_number, column_number, source_descriptor, type = nil, raw_text = nil )
         @line_number       = line_number
         @column_number     = column_number
         @source_descriptor = source_descriptor
         @type              = type.nil? ? @type : type
         @raw_text          = nil
      end
      
      def type()
         return (@type.nil? && self.length > 0 ? self : @type)
      end
      
      def raw_text()
         return (@raw_text.nil? ? self : @raw_text)
      end
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def description()
         return "Token [#{@raw_text}]; line #{@line_number} of #{@source_descriptor}"
      end

      def display( stream ) 
         stream << @raw
      end
   
   
   end # Token
   


end  # module Model
end  # module RCC
