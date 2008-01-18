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
require "#{$RCCLIB}/scanner/artifacts/node.rb"


module RCC
module Scanner
module Artifacts
module Nodes

 
 #============================================================================================================================
 # class Token
 #  - a Token produced at runtime from a source file

   class Token < Node
      
      attr_reader   :text
      attr_reader   :line_number          # The line number within the source this token came from
      attr_reader   :column_number        # The column on which this token starts (if known)
      attr_reader   :source               # Some string that describes the source of this token
      attr_accessor :rewind_position
      attr_reader   :start_position
      attr_writer   :faked
      
      
      #
      # initialize()
      #  - fill a new Token with data

      def initialize( text, start_position, line_number, column_number, source, type = nil, faked = false, follow_position = nil )
         super( type.nil? ? text : type )
         @text = text
         locate( start_position, line_number, column_number, source, type, faked, follow_position )
      end

      
      #
      # locate()
      #  - updates/sets the position an type information for this Token
      
      def locate( start_position, line_number, column_number, source, type = nil, faked = false, follow_position = nil )
         @rewind_position   = start_position
         @start_position    = start_position
         @line_number       = line_number
         @column_number     = column_number
         @source            = source
         @type              = type.nil? ? @type : type
         @faked             = faked unless faked.nil?
         @follow_position   = follow_position unless follow_position.nil?
      end
      
      
      #
      # type()
      #  - returns the type of this Token (a Symbol, String, or nil)
      
      def type()
         return (@type.nil? && @text.length > 0 ? @text : @type)
      end
      
      
      #
      # faked?()
      #  - returns true if this Token was inserted into the token stream (as opposed to coming from it)
      
      def faked?()
         return @faked
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Node support
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # first_token
      #  - returns the first token in this Node
      
      def first_token
         return self
      end
      
      
      #
      # last_token
      #  - returns the last token in this Node
      
      def last_token
         return self
      end
      
      
      #
      # token_count
      #  - returns the number of tokens in this Node
      
      def token_count
         return 1
      end
      
      
      #
      # follow_position()
      #  - returns the start position of the next Token to be produced from the source stream

      def follow_position()
         if defined?(@follow_position) then
            return @follow_position
         else
            return @start_position + length()         
         end
      end


      #
      # terminal?
      #  - returns true if this Node is represents a grammar terminal (as opposed to a non-terminal)
      
      def terminal?()
         return true
      end


      #
      # duplicate()
      #  - does a deep copy of this Node
      
      def duplicate()
         copy = self.clone
         if block_given? then
            return yield(copy)
         else
            return copy
         end
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
         return false unless (@text.length - type.length).abs < 3
         return false if @text =~ /^\w+$/ and type !~ /^\w+$/
         return false if type =~ /^\w+$/ and self !~ /^\w+$/
         
         #
         # We've establish that both operands are Strings of similar length.  Next we'll get their unique characters
         # and compare them.
         
         symbol_chars = type.split("").sort.uniq
         token_chars  = @text.split("").sort.uniq
         intersection = symbol_chars & token_chars
         
         extra_symbol_chars = symbol_chars.length - intersection.length
         extra_token_chars  = token_chars.length  - intersection.length

         return (extra_symbol_chars + extra_token_chars <= 2)
      end
      
      
      #
      # sample()
      #  - returns a sample of the source data from around this Token
      
      def sample()
         return nil unless @source.is_a?(Source)
         return @source.line(@start_position)
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
            return "[#{@text.gsub("\n", "\\n")}]" + (@type.is_a?(Symbol) ? ":#{@type}" : "")
         end
      end
      
      
      #
      # ::description()
      
      def self.description( token )
         if token.is_an?(Array) then
            return token.collect{|t| t.description}.join(", ")
         elsif token.is_a?(Token) then
            return token.description
         else
            return token.nil? ? "$" : (token.is_a?(Symbol) ? ":#{token}" : "'#{token.gsub("\n", "\\n")}'")
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << self.description << "\n"
      end
      
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Factories
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # ::fake()
      #  - builds a fake Token of the specified type
      
      def self.fake( type, follow_position = nil, start_position = nil, line_number = nil, column_number = nil, source_descriptor = nil )
         return new( "", start_position, line_number, column_number, source_descriptor, type, true, follow_position )
      end
      
      
      #
      # ::end_of_file
      #  - builds an "end of file" Token
      
      def self.end_of_file( start_position, line_number, column_number, source_descriptor )
         return new( "", start_position, line_number, column_number, source_descriptor, nil )
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # taint()
      #  - marks this Token as tainted
      #  - associates a Correction describing the taint
      
      def taint( correction )
         @corrections = [] if !defined?(@corrections) or @corrections.nil?
         @corrections << correction
         
         if correction.deletes_token? then
            deleted_token = correction.deleted_token
            if deleted_token.corrected? then
               @corrections = deleted_token.corrections + @corrections
            end
         end
      end
      
      
   end # Token
   

end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC






