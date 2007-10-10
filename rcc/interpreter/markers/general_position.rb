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
      attr_reader   :correction_cost
      attr_accessor :recovery_context
      attr_accessor :alternate_recovery_positions
      attr_accessor :sequence_number
      
      def initialize( context, node, state, lexer, stream_position, recovery_context = nil, correction_cost = 0 )
         @context          = context
         @node             = node
         @state            = state
         @recovery_context = recovery_context
         @signature        = nil
         @correction_cost  = correction_cost
         @alternate_recovery_positions = []
         @sequence_number  = (@context.nil? ? 0 : @context.sequence_number + 1)
         
         #
         # Token management
         
         @lexer                = lexer
         @stream_position      = stream_position
         @next_token           = nil
      end
      
      
      #
      # next_token()
      #  - returns the next_token from this Position
      
      def next_token( explain_indent = nil )
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
      
      
      #
      # corrected?
      #  - returns true if this position was created as a correction
      
      def corrected?
         return @correction_cost > 0
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
      
      def push( node, state, reduce_position = nil )
         next_position = nil
         
         #
         # Figure out our recovery context, if any.  This will be any recovery context that predates the
         # reduced node.
         
         recovery_context = reduce_position.nil? ? @recovery_context : reduce_position.recovery_context
         position_limit   = node.first_token.rewind_position
         position_limit   = 0 if position_limit.nil?
         while recovery_context.exists? and position_limit > recovery_context.stream_position
            recovery_context = recovery_context.recovery_context
         end

         #
         # If we are reducing, and our follow token is faked, we must propogate it.  Otherwise, we take the 
         # follow position from the node.
         
         next_position = GeneralPosition.new( self, node, state, @lexer, node.follow_position, recovery_context )
         unless reduce_position.nil? 
            if reduce_position.next_token.faked? then
               next_position.instance_eval do 
                  @next_token      = reduce_position.next_token
                  @correction_cost = reduce_position.correction_cost   # we just reduced the original off the stack
               end
            end
            
            next_position.sequence_number = reduce_position.sequence_number + 1
         end
         
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
         return AttemptPosition.new( @context, @node, @state, @lexer, @stream_position, launch_action, expected_productions, @recovery_context )
      end
      
      
      #
      # correct_by_insertion()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead
      
      def correct_by_insertion( type, recovery_context )
         correction = GeneralPosition.new( @context, @node, @state, @lexer, @read_position, recovery_context, 2 )
         
         sequence_number = @sequence_number
         follow_position = stream_position = @stream_position
         correction.instance_eval do
            @lexer.set_position( stream_position )
            @next_token = @lexer.locate_token( Token.fake(type, follow_position) )
            @next_token.rewind_position = stream_position
            @sequence_number = sequence_number
         end
         
         # correction.display( "+WFT? " )
         return correction
      end
      
      
      #
      # correct_by_deletion()
      #  - produces a new position similar to this one, but with the second next token on lookahead
      
      def correct_by_deletion( recovery_context )
         correction = GeneralPosition.new( @context, @node, @state, @lexer, self.next_token.follow_position, recovery_context, 3 )

         sequence_number = @sequence_number
         correction.instance_eval do
            @sequence_number = sequence_number
         end

         # correction.display( "-WFT? " )
         return correction
      end
      
      
      #
      # correct_by_replacement()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead, in place of the next token
      
      def correct_by_replacement( type, recovery_context )
         correction = GeneralPosition.new( @context, @node, @state, @lexer, @read_position, recovery_context, 1 )
         
         sequence_number = @sequence_number
         stream_position = @stream_position
         follow_position = next_token().follow_position
         correction.instance_eval do
            @lexer.set_position( stream_position )
            @next_token = @lexer.locate_token( Token.fake(type, follow_position) )
            @next_token.rewind_position = stream_position
            @sequence_number = sequence_number
         end

         # correction.display( "*WFT? " )
         return correction
      end
      


      
    #---------------------------------------------------------------------------------------------------------------------
    # Quality measurements and error recovery support
    #---------------------------------------------------------------------------------------------------------------------

      #
      # signature()
      #  - returns a String that identifies this Position within the Parse
      #  - if another Position returns the same signature, it has the same nodes on the "stack", is in the same state,
      #    and the lookahead is at the same place in the source
      
      def signature( include_lookahead_position = true )
         if @signature.nil? then
            @signature = (@context.nil? ? "" : @context.signature(false) + "|") + Parser.describe_type(@node.nil? ? nil : @node.type) + "," + @state.number.to_s
         end
         
         if include_lookahead_position then
            return @signature + "||#{Token.description(next_token().type)} #{next_token().start_position},#{next_token().follow_position}"
         else
            return @signature
         end
      end
      
      
      #
      # correction_count()
      #  - returns the number of corrections done to get to this position
      
      def correction_count( cache = false )
         correction_count = 0
         
         if @correction_count.nil? then
            correction_count = @recovery_context.correction_count(true) + 1 unless @recovery_context.nil?
            @correction_count = correction_count if cache
         else
            correction_count = @correction_count
         end
         
         return correction_count
      end
      
      
      #
      # active_correction_count()
      #  - returns the number of corrections currently on the stack
      
      def active_correction_count()
         @active_correction_count = (corrected? ? 1 : 0) + (@context.nil? ? 0 : @context.active_correction_count()) if @active_correction_count.nil?
         return @active_correction_count
      end
      
      
      #
      # last_active_correction()
      #  - returns the last correction currently on the stack
      
      def last_active_correction()
         if @last_active_correction.nil? then
            if corrected? then
               @last_active_correction = self
            elsif @context.nil? then
               @last_active_correction = nil
            else
               @last_active_correction = @context.last_active_correction()
            end 
         end
         
         return @last_active_correction
      end
      
      
      #
      # distance_to_last_active_correction()
      #  - returns the number steps to the last correction still on the stack, counted by sequence number
      #  - don't call this if there are no errors on the stack
      
      def distance_to_last_active_correction()
         if @distance_to_last_active_correction.nil? then
            if last_correction = last_active_correction() then
               @distance_to_last_active_correction = @sequence_number - last_correction.sequence_number
            end
         end

         return @distance_to_last_active_correction
      end
      
      #
      # distance_past_recovery_context()
      
      def distance_past_recovery_context()
         return nil if @recovery_context.nil?
         return @sequence_number - @recovery_context.sequence_number
      end
      
      
      #
      # baseline_quality()
      #  - returns a number between 0 and 20 that indicates the quality of the position with respect to 
      #    error recovery (higher numbers indicate better quality)
      #  - this version does not take into account recovery successes since the last correction
      
      def baseline_quality()
         return @baseline_quality if defined?(@baseline_quality)

         #
         # The idea is to give some estimate of how well error recovery is proceeding.  If there are no
         # corrections left on the stack, we have maximum quality of 20.  If this position is a correction,
         # we subtract the @correction_cost from either 12 (if the first error) or our context position's
         # recovery-adjusted quality.  Finally, if we are in between corrections, we use the last 
         # correction's baseline_quality, so it can be adjusted for the recovery.
         
         active_corrections = active_correction_count()
         if active_corrections == 0 then
            @baseline_quality = 20
         elsif corrected? then
            if active_corrections == 1 then
               @baseline_quality = 12 - @correction_cost
            else
               @baseline_quality = @context.quality - @correction_cost - (2 ^ (active_corrections - 1))
            end
         else
            @baseline_quality = @context.baseline_quality
         end

         #
         # Ensure the quality range is 0 to 20 and return it.
         
         @baseline_quality = max( min(@baseline_quality, 20), 0 )
         return @baseline_quality
      end
      
      
      #
      # quality()
      #  - returns a number between 0 and 20 that indicates the quality of the position with respect to 
      #    error recovery (higher numbers indicate better quality)
      #  - this version does take into account recovery successes since the last correction
      
      def quality()
         return @quality if defined?(@quality)
         @quality = baseline_quality()
         
         #
         # Adjust the baseline quality up as we get further from the last correction on the stack.
         
         @quality += self.class.reduce_distance( distance_to_last_active_correction() )
         @quality += self.class.reduce_distance( distance_past_recovery_context() )

         #
         # Ensure the quality range is 0 to 20 and return it.
         
         @quality = max( min(@quality, 20), 0 )
         return @quality
      end
      
      
      #
      # ::reduce_distance()
      #  - reduces a distance to a "relative size" as follows:
      #      0     - 0
      #      1-2   - 1
      #      3-5   - 2
      #      6-9   - 3
      #      10-14 - 4
      #      15+   - 5
      
      def self.reduce_distance( distance )
         if distance.nil? then
            return 0
         elsif distance <= 0 then
            return 0
         elsif true then
            return distance
            
            
            
         elsif distance < 3 then
            return 1
         elsif distance < 6 then
            return 2
         elsif distance < 10 then
            return 3
         elsif distance < 15 then
            return 4
         else
            return 5
         end
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
      
      def display( explain_indent )
         stack_description = description()
         stack_label       = "STACK"
         stack_bar         = "=" * (stack_description.length + stack_label.length + 3)
         
         STDOUT.puts "#{explain_indent}"
         STDOUT.puts "#{explain_indent}"
         STDOUT.puts "#{explain_indent}#{stack_bar}"
         if corrected? or true then
            STDOUT.puts "#{explain_indent}#{stack_label} #{stack_description} |      CORRECTED LOOKAHEAD: #{next_token().description}   #{next_token.line_number}:#{next_token.column_number}   positions #{next_token.start_position},#{next_token.follow_position}   quality #{quality()}"
         else
            STDOUT.puts "#{explain_indent}#{stack_label} #{stack_description} |      LOOKAHEAD: #{next_token().description}   #{next_token.line_number}:#{next_token.column_number}   positions #{next_token.start_position},#{next_token.follow_position}"
         end
         STDOUT.puts "#{explain_indent}#{stack_bar}"
         @state.display( STDOUT, "#{explain_indent}| " )
      end



      
      
   end # GeneralPosition
   


end  # module Markers
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/markers/start_position.rb"
require "#{$RCCLIB}/interpreter/markers/attempt_position.rb"
