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
require "#{$RCCLIB}/model/token.rb"

module RCC
module Interpreter

 
 #============================================================================================================================
 # class Token
 #  - a Token produced at runtime from a source file

   class Token < Model::Token
      
      attr_reader :start_position
      attr_writer :faked
      
      def locate( start_position, line_number, column_number, source_descriptor, type = nil, faked = false )
         @start_position = start_position
         @faked          = faked
         super( line_number, column_number, source_descriptor, type, nil )
         
         return self
      end
      
      def faked?()
         return @faked
      end

      def first_token
         return self
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Information and formatting
    #---------------------------------------------------------------------------------------------------------------------

    
      #
      # matches_terminal?()
      #  - returns true if this Token matches the specified Terminal
      
      def matches_terminal?( terminal )
         return (@type == terminal.type and @text == terminal.text)
      end
      
      
      #
      # similar_to?()
      #  - returns true if this Token could reasonably by replaced by one the specified type
      #  - allows for small typos that might cause a keyword to be recognized as an identifier and vice versa
      #  - allows for small typos that might cause one operator to be recognized as another 
      #  - only really useful if the specified type is a String constant
      
      def similar_to?( type )
         return @type == type unless type.is_a?(String)
         return false unless (self.length - type.length).abs < 3
         
         #
         # We've establish that both operands are Strings of similar length.  Next we'll get their unique characters
         # and compare them.
         
         symbol_chars = type.split("").sort.uniq
         token_chars  = self.split("").sort.uniq
         intersection = symbol_chars & token_chars
         
         extra_symbol_chars = symbol_chars.length - intersection.length
         extra_token_chars  = token_chars.length  - intersection.length
         
         return (extra_symbol_chars + extra_token_chars > 2)
      end
      
      
      #
      # description()
      
      def description( include_location = false )
         nyi "include_location" if include_location
         
         if @type.nil? then
            return "$"
         else
            return "[#{self.gsub("\n", "\\n")}]" + (@type.is_a?(Symbol) ? ":#{@type}" : "")
         end
      end
      
      
      #
      # ::description()
      
      def self.description( token )
         if token.is_a?(Array) then
            return token.collect{|t| t.description}.join(", ")
         elsif token.is_a?(Token) then
            return token.nil? ? "$" : token.description
         else
            return token.nil? ? "$" : (token.is_a?(Symbol) ? ":#{token}" : "'#{self.gsub("\n", "\\n")}'")
         end
      end
      
      
      #
      # display()
      
      def display( stream, indent = "" )
         stream << indent << description << "\n"
      end
      
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Factories
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # ::fake()
      #  - builds a fake Token of the specified type
      
      def self.fake( type, start_position = nil, line_number = nil, column_number = nil, source_descriptor = nil )
         return new( type.to_s ).locate( start_position, line_number, column_number, source_descriptor, type, true )
      end
      
      
      #
      # ::end_of_file
      #  - builds an "end of file" Token
      
      def self.end_of_file( start_position, line_number, column_number, source_descriptor )
         return new( "" ).locate( start_position, line_number, column_number, source_descriptor, nil )
      end





   end # Token
   


end  # module Interpreter
end  # module Rethink
