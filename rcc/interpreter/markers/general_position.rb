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
module PositionMarkers

 
 #============================================================================================================================
 # class GeneralPosition
 #  - a Position marker for the Parser

   class GeneralPosition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :node
      attr_reader   :state
      attr_reader   :token_stream
      attr_reader   :stream_position
      attr_accessor :recovery_context
      attr_accessor :alternate_recovery_positions
      
      def initialize( context, node, state, token_stream, error_context = nil )
         @context          = context
         @node             = node
         @state            = state
         @next_token       = nil
         @token_stream     = token_stream
         @stream_position  = token_stream.current_position 
         @recovery_context = error_context
         @signature        = nil
         @alternate_recovery_positions = []
      end
      
      
      #
      # in_attempt?
      #  - returns true if this position or one of our context positions is an AttemptPosition
      #  - if true, indicates the parse is currently attempting something
      
      def in_attempt?()
         return false if @context.nil?
         return @context.in_attempt?
      end
      
      
      #
      # attempt_context
      #  - returns the closest AttemptPosition from the stack
      
      def attempt_context()
         return nil if @context.nil?
         return @context.attempt_context
      end
      
      
      #
      # next_token()
      #  - reads the next token from the underlying TokenStream
      
      def next_token( explain_indent )
         @next_token = @token_stream.read( @state.lexer_plan, explain_indent ) if @next_token.nil? 
         return @next_token
      end
      
      
      #
      # push()
      #  - creates a new Position that uses this as its context
      #  - returns the new Position
      
      def push( node, state, token_stream = nil )
         error_context = @error_context
         while error_context.exists? and node.first_token.rewind_position > error_context.stream_position then
            error_context = error_context.error_context
         end
         
         return GeneralPosition.new( self, node, state, token_stream.nil? ? @token_stream : token_stream, error_context )
      end
      
      
      #
      # pop()
      #  - tells this Position it is being "popped" from the working set
      #  - pass it the top Position that was popped, so the routine can expect the chain, if necessary
      #  - returns our context Position
      
      def pop( production, top_position )
         return @context
      end
      
      
      #
      # fork()
      #  - returns an AttemptPosition that replace this position for further processing of one branch of an Attempt
      #  - call this on the original Position for each of your potential branches, then use the AttemptPositions instead
      
      def fork( launch_action, expected_productions = nil )
         return AttemptPosition.new( self, @node, @state, @token_stream, launch_action, expected_productions, @error_context )
      end
      
      
      #
      # signature()
      #  - returns a String that identifies this Position within the Parse
      #  - if another Position returns the same signature, it has the same nodes on the "stack", is in the same state,
      #    and the lookahead is at the same place in the source
      
      def signature( include_lookahead_position = true )
         if @signature.nil? then
            @signature = (@context.nil? ? @context.signature(false) + "|" : "") + Parser.describe_type(@node.type) + "," + @state.number.to_s
         end
         
         if include_lookahead_position then
            return @signature + "||" + @stream_position.to_s
         else
            return @signature
         end
      end
      
      
      #
      # correct()
      #  - produces a new position similar to this one but with an altered TokenStream for lookahead
      
      
      
   end # GeneralPosition
   


end  # module PositionMarkers
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/position_markers/start_position.rb"
require "#{$RCCLIB}/interpreter/position_markers/start_position.rb"
