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
require "#{$RCCLIB}/interpreter/corrections/correction.rb"

module RCC
module Interpreter
module PositionMarkers

 
 #============================================================================================================================
 # class PositionMarker
 #  - base class for a position markers created during parser
 #  - each position represents the head of the parser stack at the time it was created

   class PositionMarker

    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :context
      attr_reader   :node
      attr_reader   :state
      attr_reader   :stream_position
      attr_accessor :alternate_recovery_positions
      attr_accessor :sequence_number

      def initialize( context, node, state, lexer, stream_position, next_token = nil )
         @context         = context
         @node            = node
         @state           = state
         @signature       = nil
         @alternate_recovery_positions = []
         
         #
         # Token management

         @lexer            = lexer
         @stream_position  = stream_position
         @next_token       = next_token
         @sequence_number  = (@context.nil? ? 0 : @context.sequence_number + 1)
         
         #
         # Register the Position with any recovery context.  This may raise Parser::PositionSeen.
         #
         # if !recovered? and @last_correction.inserts_token? then
         #    @last_correction.recovery_context.mark_recovery_progress( self )
         # end
      end
      
      
      def start_position?()
         return false
      end
      


      #
      # next_token()
      #  - returns the next_token from this Position

      def next_token( explain_indent = nil )
         if @next_token.nil?
            @next_token = self.class.lex_token( @state, @lexer, @stream_position, explain_indent = nil )
         end

         return @next_token
      end
      
      
      #
      # each_position()
      #  - calls your block for this position and every position back to the start position
      
      def each_position()
         position = self
         until position.nil?
            yield( position )
            position = position.context
         end
      end


      #
      # each_recovery_position()
      #  - calls your block once for this position and each context position on the stack at which it 
      #    is valid to look to for error recovery options
      #  - you will never receive a recovery position that would stomp on an existing correction
      
      def each_recovery_position()
         position = self
         until position.nil?
            break if position.node.corrected? or position.next_token.corrected?
            yield( position )
            position = position.context
         end
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
      



    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------


      #
      # push()
      #  - creates a new Position that uses this as its context
      #  - returns the new Position
      #  - raises Parser::PositionSeen if you attempt to push() to a Position we've already been

      def push( node, state, reduce_position = nil )
         next_position = nil
         
         #
         # Generate the new position.  We patch up the sequence number if reducing, as it will be generated as 
         # following us, not the popped top-of-stack.
         
         next_position = PositionMarker.new( self, node, state, @lexer, node.follow_position )
         next_position.adjust_sequence_number( reduce_position ) if reduce_position.exists?
         
         #
         # Return the new Position.

         return next_position
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
         return AttemptPosition.new( @context, @node, @state, @lexer, @stream_position, launch_action, expected_productions )
      end


      #
      # correct_by_insertion()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead

      def correct_by_insertion( type )
         
         #
         # Create the token to insert.
         
         @lexer.set_position( @stream_position )
         token = @lexer.locate_token( Artifacts::Token.fake(type, @stream_position) )
         token.rewind_position = @stream_position
         token.taint( Artifacts::Insertion.new(token) )
                  
         #
         # Create the correction and a new Position to replace this one.  
         
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, token )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end


      #
      # correct_by_replacement()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead, in place of the next token

      def correct_by_replacement( type )

         #
         # Grab the copy of the token we are replacing and create the token to insert.
         
         replaced_token = next_token()
         @lexer.set_position( @stream_position )
         token = @lexer.locate_token( Artifacts::Token.fake(type, replaced_token.follow_position) )
         token.rewind_position = @stream_position
         token.taint( Artifacts::Replacement.new(token, replaced_token) )

         #
         # Create the correction and a new Position to replace this one.  

         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, token )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end


      #
      # correct_by_deletion()
      #  - produces a new position similar to this one, but with the second next token on lookahead
      
      def correct_by_deletion( explain_indent = nil )
         
         #
         # Re-arrange our lookahead.  We taint the new next Token to get the Correction in place,
         # then untaint it, as the Token is real.
         
         deleted_token = next_token()
         token = self.class.lex_token( @state, @lexer, deleted_token.follow_position, explain_indent )
         token.taint( Artifacts::Deletion.new(deleted_token) )
         token.untaint()

         #
         # Create the correction and a new Position to replace this one.
         
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, deleted_token.follow_position, token )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end


      #
      # mark_recovery_anchor()
      #  - when used as a recovery context, adds an anchor Position to our registry
      #  - raises Parser::PositionSeen if the Position has already been tried during this recovery
      
      def mark_recovery_anchor( position )
         signature = position.recovery_signature(true)
         
         @recovery_registry = {} if @recovery_registry.nil?
         if @recovery_registry.member?(signature) then
            raise Parser::PositionSeen.new( position )
         else
            @recovery_registry[signature] = true
         end
      end


      #
      # mark_recovery_progress()
      #  - when used as a recovery context, adds a progress Position to our registry
      #  - raises Parser::PositionSeen if the Position has already been tried during this recovery
      
      def mark_recovery_progress( position )
         anchor_signature   = position.recovery_signature(true)
         progress_signature = position.recovery_signature()
          
         @recovery_registry = {} if @recovery_registry.nil?
         if @recovery_registry.member?(anchor_signature) or @recovery_registry.member?(progress_signature) then
            raise Parser::PositionSeen.new( position )
         else
            @recovery_registry[progress_signature] = true
         end
      end









    #---------------------------------------------------------------------------------------------------------------------
    # Quality measurements and error recovery support
    #---------------------------------------------------------------------------------------------------------------------

      #
      # recovery_signature()
      #  - returns a String that identifies this Position within a recovery
      #  - should only be called on error Positions

      def recovery_signature( anchor_signature = false )
         if @recovery_signature.nil? then
            if @node.nil? then
               @recovery_signature = "0:#{@state.number}:0"
            else
               @recovery_signature = "#{@node.first_token.rewind_position}:#{@state.number}:#{@node.follow_position}"
            end
         end

         if anchor_signature then
            return @recovery_signature
         else
            return "#{@recovery_signature}|#{Parser.describe_type(next_token().type)}"
         end
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Output and representation
    #---------------------------------------------------------------------------------------------------------------------


      #
      # description()
      #  - return a description of this Position (node data only)

      def description( include_next_token = false )
         if @description.nil? then
            if @context.nil? or @context.node.nil? then
               @description = @node.nil? ? "" : "#{@sequence_number}:#{@node.description}#{@in_recovery ? " C" : ""}"
            else
               @description = @context.description + ", " + (@node.nil? ? "$" : "#{@sequence_number}:#{@node.description}#{@in_recovery ? " C" : ""}")
            end
         end

         if include_next_token then
            return "#{@description} | #{next_token().description}"
         else
            return @description
         end
      end


      #
      # display()

      def display( stream, explain_indent )
         stack_description = description()
         stack_label       = "STACK"
         stack_bar         = "=" * (stack_description.length + stack_label.length + 3)

         stream.puts "#{explain_indent}"
         stream.puts "#{explain_indent}"
         stream.puts "#{explain_indent}#{stack_bar}"
         # if corrected? or true then
         #    stream.puts "#{explain_indent}#{stack_label} #{stack_description} |      CORRECTED LOOKAHEAD: #{next_token().description}   #{next_token.line_number}:#{next_token.column_number}   positions #{next_token.start_position},#{next_token.follow_position}   quality #{quality()}"
         # else
            stream.puts "#{explain_indent}#{stack_label} #{stack_description} |      LOOKAHEAD: #{next_token().description}   #{next_token.line_number}:#{next_token.column_number}   positions #{next_token.start_position},#{next_token.follow_position}"
         # end
         stream.puts "#{explain_indent}#{stack_bar}"
         @state.display( stream, "#{explain_indent}| " )
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Support
    #---------------------------------------------------------------------------------------------------------------------

    protected
    

      #
      # adjust_sequence_number()
      #  - adjusts the sequence_number of this Position to follow another Position

      def adjust_sequence_number( preceding_position )
         @sequence_number = preceding_position.sequence_number + 1
         if @corrected then
            @last_correction.expand_scope( @sequence_number )
         end
      end


      #
      # ::lex_token()
      #  - returns the next_token from this Position

      def self.lex_token( state, lexer, stream_position, explain_indent = nil )
         unless explain_indent.nil? then
            lexer_explanation = "Lexing with prioritized symbols: #{state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"

            STDOUT.puts ""
            STDOUT.puts ""
            STDOUT.puts "#{explain_indent}#{"-" * lexer_explanation.length}"
            STDOUT.puts "#{explain_indent}#{lexer_explanation}"
         end

         next_token = lexer.next_token( stream_position, state.lexer_plan, explain_indent )
         next_token.rewind_position = stream_position
         
         return next_token
      end
      
      




   end # PositionMarker



end  # module PositionMarkers
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/position_markers/start_position.rb"
require "#{$RCCLIB}/interpreter/position_markers/attempt_position.rb"
