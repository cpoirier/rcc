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
      attr_reader   :position_registry

      def initialize( context, node, state, lexer, stream_position, in_recovery = false, last_correction = nil, corrected = false, position_registry = nil )
         bug( "you must supply a context or a position registry!" ) if context.nil? and position_registry.nil?
         
         @context           = context
         @node             = node
         @state            = state
         @signature        = nil
         @in_recovery      = in_recovery
         @last_correction  = last_correction
         @corrected        = corrected
         @alternate_recovery_positions = []
         
         bug( "wtf?" ) if @corrected and @last_correction.nil?

         #
         # Token management

         @lexer            = lexer
         @stream_position  = stream_position
         @next_token       = nil
         @sequence_number  = (@context.nil? ? 0 : @context.sequence_number + 1)
         
         #
         # The Position registry is how to system keeps track of where it's been.  The State table is a big graph, and,
         # during error recovery, we walk it, looking for a way to alter the source to make it work.  The Position registry
         # is how we identify when we're about to start a loop, and is shared by ALL Positions in the same "fork".  The data 
         # stored in the Position registry is the set of Position signatures we've already encountered.  At ATTEMPT forks, 
         # we fork the Position registry, so that each fork is free to try what it needs to.
         
         @position_registry = position_registry.nil? ? @context.position_registry : position_registry
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
      #  - returns true if next_token() produces a corrected token
      
      def corrected?()
         return @corrected
      end
      
      
      #
      # correctable?()
      #  - returns true if this position can be corrected
      
      def correctable?( error_tolerance = 3 )
         STDOUT.puts "====== recovered is #{recovered? ? "true" : "false"}"
         return true  if recovered?

         STDOUT.puts "====== #{@last_correction.recovery_attempts}"
         
         return false if @corrected and @last_correction.inserts_token?
         return @last_correction.recovery_attempts < error_tolerance
      end
      
      
      #
      # recovered?
      #  - returns true if this position is not past an error recovery (or there's never been an error)
      
      def recovered?()
         return @last_correction.nil? || @stream_position > @last_correction.recovery_context.stream_position
      end
      
      
      #
      # each_recovery_position()
      #  - calls your block once for this position and each context position on the stack at which it 
      #    is valid to look to for error recovery options
      #  - you will never receive a recovery position that would stomp on an existin
      
      def each_recovery_position()
         last_corrected_position = -1
         last_corrected_position = @last_correction.active_to_position unless @last_correction.nil?
         
         position = self
         until position.nil?
            print "last_corrected_position is #{last_corrected_position}; position is #{position.sequence_number}"
            break if position.sequence_number <= last_corrected_position
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
         return 0 if recovered?
         return @last_correction.recovery_attempts
      end
      
      
      #
      # recovery_cost()
      #  - returns the cost of corrections (so far) on any active recovery context
      
      def recovery_cost()
         return 0 if recovered?
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
         
         if @in_recovery and reduce_position.nil? then
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
         # Register the Position with the registry, and report any errors. 
         
         if @position_registry.member?(next_position.signature) then
            STDOUT.puts "  raising PositionSeen on #{next_position.signature}"
            raise Parser::PositionSeen.new( next_position )
         else
            STDOUT.puts "  returning #{next_position.signature}"
            @position_registry[next_position.signature] = true
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
         return AttemptPosition.new( @context, @node, @state, @lexer, @stream_position, launch_action, expected_productions, @position_registry.clone(), @in_recovery, @last_correction, @corrected )
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
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, true, Corrections::Insertion.new(token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number), true, @position_registry.clone )
         corrected_position.sequence_number = corrected_sequence_number

         return corrected_position
      end


      #
      # correct_by_replacement()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead, in place of the next token

      def correct_by_replacement( type, recovery_context )

         #
         # Create the token to insert.
         
         replaced_token = next_token()
         @lexer.set_position( @stream_position )
         token = @lexer.locate_token( Token.fake(type, replaced_token.follow_position) )
         token.rewind_position = @stream_position

         #
         # Create the correction and a new Position to replace this one.  

         corrected_sequence_number = @sequence_number
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, true, Corrections::Replacement.new(token, replaced_token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number), true, @position_registry.clone )
         corrected_position.sequence_number = corrected_sequence_number

         return corrected_position
      end


      # #
      # # correct_by_deletion()
      # #  - produces a new position similar to this one, but with the second next token on lookahead
      # 
      # def correct_by_deletion( recovery_context )
      #    correction = GeneralPosition.new( @context, @node, @state, @lexer, self.next_token.follow_position, recovery_context, 3 )
      # 
      #    sequence_number = @sequence_number
      #    correction.instance_eval do
      #       @sequence_number = sequence_number
      #    end
      # 
      #    # correction.display( "-WFT? " )
      #    return correction
      # end






    #---------------------------------------------------------------------------------------------------------------------
    # Quality measurements and error recovery support
    #---------------------------------------------------------------------------------------------------------------------

      #
      # signature()
      #  - returns a String that identifies this Position within the Parse
      #  - if another Position returns the same signature, it should not continue, as we'll already have gone there

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
            
            @signature = "#{@node.first_token.rewind_position}:#{@state.number}:#{@node.follow_position}"
            
         end

         return @signature
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Output and representation
    #---------------------------------------------------------------------------------------------------------------------


      #
      # description()
      #  - return a description of this Position (node data only)

      def description()
         if @description.nil? then
            if @context.nil? or @context.node.nil? then
               @description = @node.nil? ? "" : "#{@sequence_number}:#{@node.description}"
            else
               @description = @context.description + ", " + (@node.nil? ? "$" : "#{@sequence_number}:#{@node.description}")
            end
         end

         return @description
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
