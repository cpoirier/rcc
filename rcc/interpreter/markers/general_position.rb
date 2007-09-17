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
module Markers

 
 #============================================================================================================================
 # class GeneralPosition
 #  - a Position marker for the Parser

   class GeneralPosition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :context
      attr_reader   :node
      attr_reader   :state
      attr_reader   :stream_position
      attr_accessor :recovery_context
      attr_accessor :alternate_recovery_positions
      
      def initialize( context, node, state, lexer, stream_position, recovery_context = nil, corrected = false )
         @context          = context
         @node             = node
         @state            = state
         @recovery_context = recovery_context
         @signature        = nil
         @corrected        = corrected
         @alternate_recovery_positions = []
         
         #
         # Token management
         
         @lexer                = lexer
         @stream_position      = stream_position
         @next_token           = nil
         @next_stream_position = nil
      end
      
      
      #
      # next_token()
      #  - returns the next_token from this Position
      
      def next_token( explain_indent = nil )
         if @next_token.nil?
            @next_token = @lexer.next_token( @stream_position, @state.lexer_plan, explain_indent )
            @next_token.rewind_position = @stream_position
             @next_token.sequence_number = @context.nil? ? 0 : @context.next_token.sequence_number + 1
         end
         
         return @next_token
      end
       
      
      
      #
      # correction_count()
      #  - returns the number of corrections done to get to this position
      
      def correction_count( cache = false )
         correction_count = 0
         
         if @correction_count.nil? then
            unless @recovery_context.nil?
               correction_count = @recovery_context.correction_count(true) + 1
            end
            
            @correction_count = correction_count if cache
         else
            correction_count = @correction_count
         end
         
         return correction_count
      end
      
      
      
      #
      # corrected?
      #  - returns true if this position was created as a correction
      
      def corrected?
         return @corrected
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
      # push()
      #  - creates a new Position that uses this as its context
      #  - returns the new Position
      
      def push( node, state, reduce_position = nil )
         
         #
         # BUG: Are you sure the recovery_context should come from this Position, and not the top being reduced?
         
         recovery_context = @recovery_context
         while recovery_context.exists? and node.first_token.rewind_position > recovery_context.stream_position
            recovery_context = recovery_context.recovery_context
         end

         return GeneralPosition.new( self, node, state, @lexer, @next_stream_position, recovery_context )
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
         return AttemptPosition.new( self, @node, @state, @lexer, @stream_position, launch_action, expected_productions, @recovery_context )
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
      # correct_by_insertion()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead
      
      def correct_by_insertion( type, recovery_context )
         correction = GeneralPosition.new( @context, @node, @state, @lexer, @read_position, recovery_context, true )
         
         correction.instance_eval do
            @lexer.set_position( @stream_position )
            @next_token = @lexer.locate_token( Token.fake(type) )
            @next_token.rewind_position = @stream_position
            @next_token.sequence_number = @context.nil? ? 1 : (@context.next_token.sequence_number + 1)
            
            @next_stream_position = @stream_position
         end
         
         return correction
      end
      
      
      #
      # correct_by_deletion()
      #  - produces a new position similar to this one, but with the second next token on lookahead
      
      def correct_by_deletion( recovery_context )
         self.next_token()
         return GeneralPosition.new( @context, @node, @state, @lexer, @next_stream_position, recovery_context, true )
      end
      
      
      #
      # correct_by_replacement()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead, in place of the next token
      
      def correct_by_replacement( type, recovery_context )
         next_stream_position = self.next_token.follow_position
         correction = correct_by_insertion( type, recovery_context )
         
         correction.instance_eval do
            @next_stream_position = next_stream_position
         end
         
         return correction
      end
      
      
      
   end # GeneralPosition
   


end  # module Markers
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/markers/start_position.rb"
require "#{$RCCLIB}/interpreter/markers/attempt_position.rb"
