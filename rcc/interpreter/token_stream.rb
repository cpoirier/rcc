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
      
      class RewindLimitReached < Exception
      end
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( lexer, faked_lookahead = [] )
         @lexer                   = lexer
         @lookahead               = []
         @lexer_plan              = nil
         @rewind_limit            = faked_lookahead.length > 0 ? faked_lookahead[0].start_position : @lexer.position
         p "ON CONSTRUCTION rewind limit is #{@rewind_limit}"
         
         @pending_faked_lookahead = faked_lookahead
         @used_faked_lookahead    = []
         
         @pending_faked_lookahead.each do |token|
            token.faked = true
         end
      end
      
      def position()
         return @lexer.position
      end
      
      
      #
      # fake_token()
      #  - produces a fake Token of the specified type at the current lexer position
      
      def fake_token( type )
         return @lexer.locate_token( Token.fake(type) )
      end
      
      
      #
      # set_lexer_plan()
      #  - swaps in a new LexerPlan for use with la() and consume()
      #  - takes the appropriate action to ensure the next token is from that new plan
      #  - doesn't do unecessary work
      
      def lexer_plan=( plan )
         unless plan.object_id == @lexer_plan.object_id
            unless @lookahead.empty?
               rewind( @pending_faked_lookahead.empty? ? @lookahead[0] : @pending_faked_lookahead[0] )
               @lookahead.clear
            end
            
            @lexer_plan = plan
         end
      end
    
      
      #
      # la()
      #  - looks ahead one or more tokens
      
      def la( count = 1, explain = false, indent = "" )
         return @pending_faked_lookahead[count - 1] if count <= @pending_faked_lookahead.length
         
         until @lookahead.length >= count
            if token = @lexer.next_token(@lexer_plan, explain, indent) then
               @lookahead << token
            else
               nyi "error handling for lexer error" if @lexer.input_remaining?
               break
            end
         end
         
         token = @lookahead[count-1]
         STDOUT.puts "#{indent}===> RETURNING #{token.description} at #{token.line_number}:#{token.column_number}, position #{token.start_position}" if explain

         return token
      end
      
      
      #
      # consume()
      #  - shifts the next token off the lookahead and returns it
      
      def consume( explain = false, indent = "" )
         la(1, explain, indent)
         if @pending_faked_lookahead.empty? then
            return @lookahead.shift
         else
            token = @pending_faked_lookahead.shift
            @used_faked_lookahead << token
            return token
         end
      end
      
      
      #
      # rewind()
      #  - rewinds the lexer to where it was when it produced the specified token
      
      def rewind( before_token )
         p "REWINDING"
         p before_token.start_position
         p @rewind_limit
         if before_token.start_position >= @rewind_limit then 
            p "INSIDE"
            p @lexer.position
            @lexer.reset_position( before_token.start_position )
            p @lexer.position
            @lookahead.clear
         
            if before_token.faked? then
               index = -1
               @used_faked_lookahead.each_index do |search_index|
                  if before_token.object_id == @used_faked_lookahead[search_index].object_id then
                     index = search_index
                     break
                  end
               end
            
               if index > -1 then
                  tokens = @used_faked_lookahead.slice!(index..-1)
                  @pending_faked_lookahead[0, 0] = tokens
               end
            end
         else
            STDOUT.puts "#{before_token.description} at [#{before_token.start_position}]; rewind_limit: #{@rewind_limit}"
            raise RewindLimitReached.new()
         end
      end
      

      #
      # cover()
      #  - returns a copy of this TokenStream that starts where this one is currently
      #  - you shouldn't try to rewind it past its start point 
      
      def cover( faked_lookahead = [] )
         rewind( @lookahead[0] ) unless @lookahead.empty?()
         token_stream = TokenStream.new( @lexer, faked_lookahead + @pending_faked_lookahead )
         token_stream.lexer_plan = @lexer_plan
         
         return token_stream
      end



      
   end # TokenStream
   


end  # module module
end  # module Rethink
