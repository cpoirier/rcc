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


      #
      # ::fake()
      #  - builds a fake Token of the specified type
      
      def self.fake( type, start_position = nil, line_number = nil, column_number = nil, source = nil, footprint = nil )
         return new( "", type, start_position, line_number, column_number, source, footprint, true )
      end
      
      
      #
      # ::end_of_file
      #  - builds an "end of file" Token
      
      def self.end_of_file( start_position, line_number, column_number, source )
         return new( "", Name.end_of_file_type, start_position, line_number, column_number, source )
      end



      #
      # ::hypothetical()
      #  - returns a hypothetical token useful as a placeholder
      
      def self.hypothetical()
         return @@hypothetical_token
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and data
    #---------------------------------------------------------------------------------------------------------------------
    
      
      attr_reader   :text
      attr_reader   :characters           # The Unicode character codes in the Token text
      attr_reader   :line_number          # The line number within the source this token came from
      attr_reader   :column_number        # The column on which this token starts (if known)
      attr_reader   :source               # Some string that describes the source of this token
      attr_reader   :start_position
      attr_reader   :footprint
      attr_writer   :faked
      
      
      #
      # initialize()
      #  - fill a new Token with data

      def initialize( characters, type, start_position, line_number, column_number, source, footprint = nil, faked = false )
         case characters
         when Array
            @characters = characters
            @text       = characters.pack("U*")
         when String
            @characters = characters.unpack("U*")
            @text       = characters
         else
            bug( "unsupported token data type [#{characters.class.name}]" )
         end

         super( type.nil? ? Name.new(text) : type )
         
         @start_position = start_position
         @line_number    = line_number
         @column_number  = column_number
         @source         = source
         @faked          = faked if faked
         @footprint      = footprint.nil? ? start_position..(start_position + @characters.length - 1) : footprint
         
         ignore_errors { @text.source = self }
      end

      def length()
         return @characters.length
      end

      def rewind_position()
         return @footprint.begin
      end
      
      
      #
      # faked?()
      #  - returns true if this Token was inserted into the token stream (as opposed to coming from it)
      
      def faked?()
         return @faked
      end
      
      
      #
      # to_s()
      
      def to_s()
         return @text
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
         return @footprint.end + 1
      end


      #
      # commit()
      #  - cleans up after a parse is committed (won't require error recovery)
      
      def commit()
         @footprint = nil
      end


      #
      # token?
      #  - returns true if this Node is a Token
      
      def token?()
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
      # similar_to?()
      #  - returns true if this Token could reasonably by replaced by one the specified type
      #  - allows for small typos that might cause a keyword to be recognized as an identifier and vice versa
      #  - allows for small typos that might cause one operator to be recognized as another 
      #  - only really useful if the specified type is a String constant
      
      def similar_to?( type )
         return @type == type unless type.literal?

         exemplar = type.name
         return false unless (@text.length - exemplar.length).abs < 3
         return false if @text =~ /^\w+$/ and exemplar !~ /^\w+$/
         return false if exemplar =~ /^\w+$/ and @text !~ /^\w+$/
         
         #
         # We've establish that both operands are of similar length.  Next we'll get 
         # their unique characters and compare them.
         
         symbol_chars = exemplar.split("").sort.uniq
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
         if @source.nil?
            return nil
         else
            return @source.sample_line( @start_position )[0]
         end
      end
            
      def sample_and_mark( spacer = "-", marker = "^" )
         if @source.nil?
            return nil
         else
            return @source.sample_line_and_mark_position( spacer, marker, @start_position )
         end
      end


      #
      # description()
      
      def description( include_location = false )
         nyi "include_location" if include_location
         
         if @type.eof? then
            return "$"
         elsif @faked then
            return "FAKE[" + (@type.literal? ? @type.name : "") + "]" + (@type.literal? ? "" : ":" + @type.description)
         else
            return "[#{@text.escape}]" + (@type.literal? ? "" : ":#{@type.description}" )
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
            nyi()
            return token.nil? ? "$" : (token.is_a?(Symbol) ? ":#{token}" : "'#{token.gsub("\n", "\\n")}'")
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << self.description << "\n"
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
      
      
      #
      # untaint()
      
      def untaint()
         @untainted = true
      end
      
      
      #
      # tainted?
      #  - returns true if this CSN carries Correction taint
      
      def tainted?()
         return (corrected? and !untainted?())
      end
      
      
      #
      # untainted?
      
      def untainted?()
         return (defined?(@untainted) and @untainted)
      end
      




      @@hypothetical_token = new( "", Name.any_type, -1, 0, 0, nil, nil, true )

      
   end # Token
   

end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC






