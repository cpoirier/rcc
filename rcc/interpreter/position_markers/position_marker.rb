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
      attr_reader   :last_correction
      attr_accessor :alternate_recovery_positions
      attr_accessor :sequence_number

      def initialize( context, node, state, lexer, stream_position, in_recovery = false, last_correction = nil, corrected = false )
         @context         = context
         @node            = node
         @state           = state
         @signature       = nil
         @in_recovery     = in_recovery
         @last_correction = last_correction
         @corrected       = corrected
         @alternate_recovery_positions = []
         
         bug( "wtf?" ) if @corrected and @last_correction.nil?
         
         #
         # Token management

         @lexer            = lexer
         @stream_position  = stream_position
         @next_token       = nil
         @sequence_number  = (@context.nil? ? 0 : @context.sequence_number + 1)
         
         #
         # Register the Position with any recovery context.  This may raise Parser::PositionSeen.
         
         if @in_recovery then
            @last_correction.recovery_context.add_recovery_position( self ) if @last_correction.inserts_token?
         end
      end


      #
      # next_token()
      #  - returns the next_token from this Position

      def next_token( explain_indent = nil )
         if @corrected and @last_correction.inserts_token? then
            return @last_correction.inserted_token 
         else
            if @next_token.nil?
               unless explain_indent.nil? then
                  lexer_explanation = "Lexing with prioritized symbols: #{@state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"

                  STDOUT.puts ""
                  STDOUT.puts ""
                  STDOUT.puts "#{explain_indent}#{"-" * lexer_explanation.length}"
                  STDOUT.puts "#{explain_indent}#{lexer_explanation}"
               end

               @next_token = @lexer.next_token( @stream_position, @state.lexer_plan, explain_indent )
               @next_token.rewind_position = @stream_position
            end

            return @next_token
         end
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
      # in_recovery?
      #  - returns true if this position is part of an uncomplete error recovery
      
      def in_recovery?()
         return @in_recovery
      end
      
      
      #
      # corrected?
      #  - returns true if this position was the result of a correction
      
      def corrected?()
         return @corrected
      end
      
      
      #
      # corrected_token?
      #  - returns true if the next_token is faked
      
      def corrected_token?()
         return next_token.faked?
      end
      
      
      #
      # correctable?()
      #  - returns true if this position can be corrected
      
      def correctable?( error_tolerance = 3 )
         return true  if recovered?

         return false if @corrected and @last_correction.inserts_token?
         return @last_correction.recovery_attempts < error_tolerance
      end
      
      
      #
      # recovered?
      #  - returns true if this position is past an error recovery (or there's never been an error)
      
      def recovered?()
         return true if @last_correction.nil?
         if @stream_position > @last_correction.recovery_context.stream_position then
            
            #
            # We want to make sure the token that caused the error has actually been REDUCEd off
            # the stack.  If it hasn't, we're probably not really past the error.
            
            recovered = true
            each_position do |position|
               break if position.stream_position < @last_correction.recovery_context.stream_position
               if position.node.is_a?(Token) then
                  if position.stream_position == @last_correction.recovery_context.stream_position then
                     recovered = false
                     break
                  end
               end
            end
            
            return recovered
         else
            return false
         end
      end
      
      
      #
      # each_recovery_position()
      #  - calls your block once for this position and each context position on the stack at which it 
      #    is valid to look to for error recovery options
      #  - you will never receive a recovery position that would stomp on an existing correction
      
      def each_recovery_position()
         recovery_stream_position = -1
         recovery_stream_position = @last_correction.recovery_context.stream_position unless @last_correction.nil?
         
         position = self
         until position.nil?
            break if position.stream_position < recovery_stream_position
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
      
      
      #
      # error_count()
      #  - returns the number of errors we've encountered getting to here
      
      def error_count()
         return 0 if @last_correction.nil?
         return @last_correction.error_count
      end
      
      
      #
      # recovery_attempts()
      #  - returns the number of corrections (so far) on any active recovery context
      
      def recovery_attempts()
         return 0 if !@corrected and recovered? 
         return @last_correction.recovery_attempts
      end
      
      
      #
      # recovery_cost()
      #  - returns the cost of corrections (so far) on any active recovery context
      
      def recovery_cost()
         return 0 if (recovered? and not @corrected)
         return @last_correction.recovery_cost
      end
      
      
      #
      # correction_cost()
      #  - returns the overall cost of corrections to this point in the parse
      
      def correction_cost()
         return 0 if @last_correction.nil?
         return @last_correction.correction_cost 
      end
      
      
      #
      # recovery_context()
      #   - returns the recovery_context from the last correction
      
      def recovery_context()
         return nil if @last_correction.nil?
         return @last_correction.recovery_context
      end
      
      
      #
      # add_recovery_position()
      #  - when used as a recovery context, adds a Position to our registry
      #  - raises Parser::PositionSeen if the Position has already been tried during this recovery
      
      def add_recovery_position( position )
         @recovery_registry = {} if @recovery_registry.nil?
         if @recovery_registry.member?(position.signature) then
            raise Parser::PositionSeen.new( position )
         else
            @recovery_registry[position.signature] = true
         end
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
         next_position    = nil
         next_in_recovery = @in_recovery
         
         #
         # If we are in recovery, and this push() shifts us past the recovery context stream position,
         # we are done with error recovery.
         
         if @in_recovery then
            next_in_recovery = false if node.follow_position > @last_correction.recovery_context.stream_position
         end
         
         #
         # Generate the new position.  We patch up the sequence number if reducing, as it will be generated as 
         # following us, not the popped top-of-stack.
         
         if reduce_position.nil? then
            next_position = PositionMarker.new( self, node, state, @lexer, node.follow_position, next_in_recovery, @last_correction, false )
         else
            next_position = PositionMarker.new( self, node, state, @lexer, node.follow_position, next_in_recovery, reduce_position.last_correction, reduce_position.corrected? )
            next_position.adjust_sequence_number( reduce_position )
         end
         
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
         return AttemptPosition.new( @context, @node, @state, @lexer, @stream_position, launch_action, expected_productions, @in_recovery, @last_correction, @corrected )
      end


      #
      # correct_by_insertion()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead

      def correct_by_insertion( type, recovery_context )
         
         #
         # Create the token to insert.
         
         @lexer.set_position( @stream_position )
         token = @lexer.locate_token( Token.fake(type, @stream_position) )
         token.rewind_position = @stream_position
                  
         #
         # Create the correction and a new Position to replace this one.  
         
         corrected_sequence_number = @sequence_number
         correction         = Corrections::Insertion.new( token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number )
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, true, correction, true )
         corrected_position.sequence_number = corrected_sequence_number

         return corrected_position
      end


      #
      # correct_by_replacement()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead, in place of the next token

      def correct_by_replacement( type, recovery_context )

         #
         # Grab the copy of the token we are replacing and create the token to insert.
         
         replaced_token = next_token()
         @lexer.set_position( @stream_position )
         token = @lexer.locate_token( Token.fake(type, replaced_token.follow_position) )
         token.rewind_position = @stream_position

         #
         # Create the correction and a new Position to replace this one.  

         corrected_sequence_number = @sequence_number
         correction         = Corrections::Replacement.new( token, replaced_token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number )
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, true, correction, true )
         corrected_position.sequence_number = corrected_sequence_number

         return corrected_position
      end


      #
      # correct_by_deletion()
      #  - produces a new position similar to this one, but with the second next token on lookahead
      
      def correct_by_deletion( recovery_context )
         
         #
         # Grab the copy of the token we are deleting.
         
         deleted_token = next_token()

         #
         # Create the correction and a new Position to replace this one.
         
         corrected_sequence_number = @sequence_number
         correction         = Corrections::Deletion.new( deleted_token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number )
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, self.next_token.follow_position, true, correction, true )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Quality measurements and error recovery support
    #---------------------------------------------------------------------------------------------------------------------

      #
      # signature()
      #  - returns a String that identifies this Position within the Parse
      #  - should only be called on error Positions

      def signature()
         if @signature.nil? then
            
            #
            # This version of the signature is much simpler than the first versions.  We consider two things:
            # the state number; and the source extent of our Node.  This is all that is needed to verify if two
            # signatures are identical, and putting too much information in the signature is why the previous
            # versions proved unhelpful for loop detection.
            #
            # When in a state, only one thing determines the next action: the lookahead.  Therefore, if we are
            # in the same state, and the lookahead is at the same position in the source, the same behaviour is 
            # going to result.  In other words, we are in a loop.
            #
            # However: a REDUCE can move the parse without changing the state or the lookahead position.  Consider 
            # the expression "e + e + e" in a right-associative grammar.  If we reduce the right "e + e" to "e", we 
            # likely end up in the same state, with the same lookahead, but we have, in fact, made progress.  
            # Therefore, we include the start position of the node, as well as its end.

            
            if @node.nil? then
               @signature = "0:#{@state.number}:0|#{Parser.describe_type(next_token().type)}"
            else
               @signature = "#{@node.first_token.rewind_position}:#{@state.number}:#{@node.follow_position}|#{Parser.describe_type(next_token().type)}"
            end
         end

         return @signature
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
               @description = @node.nil? ? "" : "#{@sequence_number}:#{@node.description}"
            else
               @description = @context.description + ", " + (@node.nil? ? "$" : "#{@sequence_number}:#{@node.description}")
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





   end # PositionMarker



end  # module PositionMarkers
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/position_markers/start_position.rb"
require "#{$RCCLIB}/interpreter/position_markers/attempt_position.rb"
