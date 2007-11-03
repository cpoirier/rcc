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
module Artifacts

 
 #============================================================================================================================
 # class Token
 #  - a Token produced at runtime from a source file

   class Token < Model::Token
      
      attr_accessor :rewind_position
      attr_reader   :start_position
      attr_writer   :faked

      def locate( start_position, line_number, column_number, source_descriptor, type = nil, faked = false, follow_position = nil )
         @rewind_position = start_position
         @start_position  = start_position
         @faked           = faked unless faked.nil?
         @follow_position = follow_position unless follow_position.nil?
         super( line_number, column_number, source_descriptor, type, nil )
         
         return self
      end
      
      def faked?()
         return @faked
      end

      def first_token
         return self
      end
      
      def last_token
         return self
      end
      
      def token_count
         return 1
      end
      
      def follow_position()
         if defined?(@follow_position) then
            return @follow_position
         else
            return @start_position + length()         
         end
      end
      
      def terminal?()
         return true
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
         return false if self =~ /^\w+$/ and type !~ /^\w+$/
         return false if type =~ /^\w+$/ and self !~ /^\w+$/
         
         #
         # We've establish that both operands are Strings of similar length.  Next we'll get their unique characters
         # and compare them.
         
         symbol_chars = type.split("").sort.uniq
         token_chars  = self.split("").sort.uniq
         intersection = symbol_chars & token_chars
         
         extra_symbol_chars = symbol_chars.length - intersection.length
         extra_token_chars  = token_chars.length  - intersection.length

         return (extra_symbol_chars + extra_token_chars <= 2)
      end
      
      
      #
      # description()
      
      def description( include_location = false )
         nyi "include_location" if include_location
         
         if @type.nil? then
            return "$"
         elsif @faked then
            return "FAKE[" + (@type.is_a?(Symbol) ? ":#{@type}" : "#{@type.gsub("\n", "\\n")}") + "]"
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
            return token.description
         else
            return token.nil? ? "$" : (token.is_a?(Symbol) ? ":#{token}" : "'#{token.gsub("\n", "\\n")}'")
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
      
      def self.fake( type, follow_position = nil, start_position = nil, line_number = nil, column_number = nil, source_descriptor = nil )
         return new( "" ).locate( start_position, line_number, column_number, source_descriptor, type, true, follow_position )
      end
      
      
      #
      # ::end_of_file
      #  - builds an "end of file" Token
      
      def self.end_of_file( start_position, line_number, column_number, source_descriptor )
         return new( "" ).locate( start_position, line_number, column_number, source_descriptor, nil )
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # tainted?
      #  - returns true if this Token carries Correction taint
      
      def tainted?()
         return (defined(@corrections) and @corrections.exists? and !@corrections.empty?)
      end
      
      
      #
      # taint()
      #  - marks this Token as tainted
      #  - associates a Correction describing the taint
      
      def taint( correction )
         @corrections = [] if !defined(@corrections) or @corrections.nil?
         @corrections << correction
         
         if correction.deletes_token? then
            deleted_token = correction.deleted_token
            if deleted_token.corrected? then
               @corrections = deleted_token.corrections + @corrections
            end
         end
      end
      
      
      #
      # corrected?()
      #  - returns true if there are any Corrections associated with this Token
      #  - for Tokens (only), tainted? implies corrected? and vice versa
      
      def corrected?()
         return (defined(@corrections) and @corrections.exists? and !@corrections.empty?)
      end
      
      
      #
      # corrections()
      #  - returns any Correction objects associated with this Token
      
      def corrections()
         return [] if !defined(@corrections)
         return @corrections 
      end
      
      
      #
      # corrections_cost()
      #  - returns the cost of any Corrections associated with this Token, or 0
      
      def corrections_cost()
         return 0 if !defined(@corrections) or @corrections.nil?
         return @corrections.inject(0) { |current, correction| current + correction.cost }
      end
      
      
   end # Token
   

end  # module Artifacts
end  # module Interpreter
end  # module Rethink
