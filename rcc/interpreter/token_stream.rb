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

module RCC
module Interpreter

 
 #============================================================================================================================
 # class TokenStream
 #  - manages a stream of Tokens, derived from a Lexer, on behalf of the Parser

   class TokenStream
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( lexer, faked_lookahead = [] )
         @lexer                   = lexer
         @lookahead               = []
         @lexer_plan              = nil
         
         @pending_faked_lookahead = faked_lookahead
         @used_faked_lookahead    = []
         
         @pending_faked_lookahead.each do |token|
            token.faked = true
         end
      end
      
      
      #
      # set_lexer_plan()
      #  - swaps in a new LexerPlan for use with la() and consume()
      #  - takes the appropriate action to ensure the next token is from that new plan
      #  - doesn't do unecessary work
      
      def lexer_plan=( plan )
         unless plan.object_id == @lexer_plan.object_id
            unless @lookahead.empty?
               rewind( @lookahead[0] )
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
         
         return @lookahead[count-1]
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
         @lexer.reset_position( before_token.start_position )
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
