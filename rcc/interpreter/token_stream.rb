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

module RCC
module Interpreter

 
 #============================================================================================================================
 # class TokenStream
 #  - manages a stream of Tokens, derived from a Lexer, on behalf of the Parser

   class TokenStream
      
      class PositionOutOfRange < Exception
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :start_sequence_number
      attr_reader :sequence_number
    
      def initialize( lexer, start_position = 0, seed_tokens = [], start_sequence_number = 0 )
         @lexer            = lexer                   # The Lexer we'll use to produce our Tokens
         @start_position   = start_position          # The first position to read from the lexer
         @current_position = start_position          # The next position to read from the lexer
         @seed_tokens      = seed_tokens             # A set of (possibly faked) Tokens to be produced before reading from the lexer
         
         @start_sequence_number = start_sequence_number   # The sequence number at which our Tokens start
         @sequence_number       = start_sequence_number   # A "sequence number" to be assigned to Tokens we generate

         #
         # We tell our seed tokens apart from our real tokens by using a negative rewind position that indicates
         # the @seed_token number.  While we're at it, assign the sequence numbers, as they will not change for
         # the seed tokens.
         
         number = 1
         sequence_number = @sequence_number
         @seed_tokens.each do |seed_token|
            seed_token.rewind_position = -number
            seed_token.sequence_number = sequence_number
            number          += 1
            sequence_number += 1
         end
         
         @unread_seed_tokens = [] + @seed_tokens
         @last_read          = nil
         @last_peek          = nil
      end
      
      
      #
      # restart()
      #  - sets the position back to the first Token producible by this TokenStream
      
      def restart()
         @current_position   = @start_position
         @sequence_number    = @start_sequence_number
         @unread_seed_tokens = [] + @seed_tokens 
         
         @last_read = nil
         @last_peek = nil
      end
      
      
      #
      # position_before()
      #  - sets the position so that it is ready to re-lex the specified Token
      
      def position_before( token )
         @last_read = nil
         
         if token.rewind_position >= 0 then
            raise PositionOutOfRange.new() if token.rewind_position < @start_position
            @current_position = token.rewind_position
         else
            raise PositionOutOfRange.new() unless @seed_tokens.member?(token)
            @unread_seed_tokens = @seed_tokens.slice( (-token.rewind_position - 1)..-1 )
            @current_position = @start_position
         end
         
         @sequence_number = token.sequence_number
      end
      
      
      #
      # position_after()
      #  - sets the position so that it is ready to lex the next Token
      
      def position_after( token )
         @last_read = nil

         if token.rewind_position >= 0 then
            raise PositionOutOfRange.new() if token.rewind_position < @start_position
            @current_position = token.start_position + token.length
         else
            if @unread_seed_tokens.empty? or -token.rewind_position + 1 != -@unread_seed_tokens[0].rewind_position then
               raise PositionOutOfRange.new() unless @seed_tokens.member?(token)
               @unread_seed_tokens = @seed_tokens.slice( (-token.rewind_position)..-1 )
               # assert( !@unread_seed_tokens.nil?, "wtf: #{token.rewind_position}; #{@seed_tokens.length}")
            end
            @current_position = @start_position
         end

         @sequence_number = token.sequence_number + 1
      end
          
      
      #
      # read()
      #  - reads a Token from the current position, using the supplied LexerPlan
      #  - advances the position of the TokenStream
      
      def read( lexer_plan, explain_indent = nil )
         if @unread_seed_tokens.empty? then
            @last_read = @lexer.next_token( @current_position, lexer_plan, explain_indent )
            @last_read.rewind_position = @current_position
            @last_read.sequence_number = @sequence_number
            @sequence_number += 1
            @current_position = @lexer.position
         else
            @last_read = @unread_seed_tokens.shift
         end
         
         return @last_read
      end
      
      
      #
      # peek()
      #  - reads a Token from the current or specified position, using the supplied LexerPlan
      #  - does not advance the position of the TokenStream
      
      def peek( lexer_plan, explain_indent = nil )
         return peek_after( @last_read, lexer_plan, explain_indent )
      end
         
         
      #
      # peek_after()
      #  - reads a Token from after the specified Token, using the supplied LexerPlan
      #  - does not advance the position of the TokenStream
      
      def peek_after( token, lexer_plan, explain_indent = nil )
         position        = @current_position
         sequence_number = @sequence_number

         if token.nil? then
            unless @unread_seed_tokens.empty?
               @last_read = @unread_seed_tokens.shift
               return @last_read
            end
         else
            
            #
            # If the supplied token's rewind_position is less than zero, it is one of our seed tokens, and so
            # requires special handling.
         
            if token.rewind_position < 0 then
               number = -token.rewind_position
               if number <= @seed_tokens.length then
                  return @seed_tokens[number - 1]
               end
         
            #
            # Otherwise it is a real Token, and we need to calculate an offset.  Note that we use the start_position,
            # not the rewind_position, because the end of the token (and therefore the start of the next) can only
            # be measured from the start_position -- the rewind_position allows the system to account for characters
            # not actually in the token (ignored tokens and such).
         
            else
               position = token.start_position + token.length
            end

            sequence_number = token.sequence_number + 1
         end
         
         
         #
         # If we are still here, lex a Token.
         
         token = @lexer.next_token( position, lexer_plan, explain_indent )
         token.rewind_position = position
         token.sequence_number = sequence_number
         
         return token
      end
      
      
      
      #
      # fake_token()
      #  - produces a fake Token of the specified type at the current lexer position
      
      def fake_token( type, at_token = nil )
         token = nil 
         
         if at_token.nil? then
            token = @lexer.locate_token( Token.fake(type) )
            token.rewind_position = @current_position
            token.sequence_number = @sequence_number
         else
            token = Token.fake( type, at_token.start_position, at_token.line_number, at_token.column_number, at_token.source_descriptor )
            token.rewind_position = at_token.rewind_position
            token.sequence_number = at_token.sequence_number
         end
         
         return token
      end
      
      

      #
      # cover()
      #  - returns a copy of this TokenStream that starts where this one is currently
      #  - you shouldn't try to rewind it past its start point 
      
      def cover( seed_tokens = [] )
         return TokenStream.new( @lexer, @current_position, seed_tokens + @unread_seed_tokens, @sequence_number )
      end



      
   end # TokenStream
   


end  # module module
end  # module Rethink
