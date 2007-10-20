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
         @context          = context
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
         last_corrected_position = @last_correction.position_number unless @last_correction.nil?
         
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
         # Generate the new position and return it.  We patch up the sequence number if reducing, as it will
         # be generated as following us, not the popped top-of-stack.
         
         if reduce_position.nil? then
            next_position = PositionMarker.new( self, node, state, @lexer, node.follow_position, next_in_recovery, @last_correction, false )
         else
            next_position = PositionMarker.new( self, node, state, @lexer, node.follow_position, next_in_recovery, reduce_position.last_correction, reduce_position.corrected? )
            if reduce_position.last_correction.exists? and reduce_position.last_correction.position_number == reduce_position.sequence_number then
               reduce_position.last_correction.increment_position_number
            end
         end

         unless reduce_position.nil?
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
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, true, Corrections::Insertion.new(token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number), true )
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
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, true, Corrections::Replacement.new(token, replaced_token, in_recovery? ? @last_correction.recovery_context : recovery_context, @last_correction, corrected_sequence_number), true )
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


      # #
      # # correction_count()
      # #  - returns the number of corrections done to get to this position
      # 
      # def correction_count( cache = false )
      #    correction_count = 0
      # 
      #    if @correction_count.nil? then
      #       correction_count = @recovery_context.correction_count(true) + 1 unless @recovery_context.nil?
      #       @correction_count = correction_count if cache
      #    else
      #       correction_count = @correction_count
      #    end
      # 
      #    return correction_count
      # end
      # 
      # 
      # #
      # # active_correction_count()
      # #  - returns the number of corrections currently on the stack
      # 
      # def active_correction_count()
      #    @active_correction_count = (corrected? ? 1 : 0) + (@context.nil? ? 0 : @context.active_correction_count()) if @active_correction_count.nil?
      #    return @active_correction_count
      # end
      # 
      # 
      # #
      # # last_active_correction()
      # #  - returns the last correction currently on the stack
      # 
      # def last_active_correction()
      #    if @last_active_correction.nil? then
      #       if corrected? then
      #          @last_active_correction = self
      #       elsif @context.nil? then
      #          @last_active_correction = nil
      #       else
      #          @last_active_correction = @context.last_active_correction()
      #       end 
      #    end
      # 
      #    return @last_active_correction
      # end
      # 
      # 
      # #
      # # distance_to_last_active_correction()
      # #  - returns the number steps to the last correction still on the stack, counted by sequence number
      # #  - don't call this if there are no errors on the stack
      # 
      # def distance_to_last_active_correction()
      #    if @distance_to_last_active_correction.nil? then
      #       if last_correction = last_active_correction() then
      #          @distance_to_last_active_correction = @sequence_number - last_correction.sequence_number
      #       end
      #    end
      # 
      #    return @distance_to_last_active_correction
      # end
      # 
      # #
      # # distance_past_recovery_context()
      # 
      # def distance_past_recovery_context()
      #    return nil if @recovery_context.nil?
      #    return @sequence_number - @recovery_context.sequence_number
      # end
      # 
      # 
      # #
      # # baseline_quality()
      # #  - returns a number between 0 and 20 that indicates the quality of the position with respect to 
      # #    error recovery (higher numbers indicate better quality)
      # #  - this version does not take into account recovery successes since the last correction
      # 
      # def baseline_quality()
      #    return @baseline_quality if defined?(@baseline_quality)
      # 
      #    #
      #    # The idea is to give some estimate of how well error recovery is proceeding.  If there are no
      #    # corrections left on the stack, we have maximum quality of 20.  If this position is a correction,
      #    # we subtract the @correction_cost from either 12 (if the first error) or our context position's
      #    # recovery-adjusted quality.  Finally, if we are in between corrections, we use the last 
      #    # correction's baseline_quality, so it can be adjusted for the recovery.
      # 
      #    active_corrections = active_correction_count()
      #    if active_corrections == 0 then
      #       @baseline_quality = 20
      #    elsif corrected? then
      #       if active_corrections == 1 then
      #          @baseline_quality = 12 - @correction_cost
      #       else
      #          @baseline_quality = @context.quality - @correction_cost - (2 ^ (active_corrections - 1))
      #       end
      #    else
      #       @baseline_quality = @context.baseline_quality
      #    end
      # 
      #    #
      #    # Ensure the quality range is 0 to 20 and return it.
      # 
      #    @baseline_quality = max( min(@baseline_quality, 20), 0 )
      #    return @baseline_quality
      # end
      # 
      # 
      # #
      # # quality()
      # #  - returns a number between 0 and 20 that indicates the quality of the position with respect to 
      # #    error recovery (higher numbers indicate better quality)
      # #  - this version does take into account recovery successes since the last correction
      # 
      # def quality()
      #    return @quality if defined?(@quality)
      #    @quality = baseline_quality()
      # 
      #    #
      #    # Adjust the baseline quality up as we get further from the last correction on the stack.
      # 
      #    @quality += self.class.reduce_distance( distance_to_last_active_correction() )
      #    @quality += self.class.reduce_distance( distance_past_recovery_context() )
      # 
      #    #
      #    # Ensure the quality range is 0 to 20 and return it.
      # 
      #    @quality = max( min(@quality, 20), 0 )
      #    return @quality
      # end
      # 
      # 
      # def correction_density()
      #    if @correction_density.nil? then
      #       @correction_count = (corrected? ? 1 : 0)
      #       @correction_span  = 1
      # 
      #       end_at   = @recovery_context.sequence_number
      #       start_at = @sequence_number
      # 
      #       context = @context
      #       pending_count = 0
      #       until context.nil?
      #          pending_count += 1
      # 
      #          if context.corrected? then
      #             if context.recovery_context.sequence_number == end_at then
      #                @correction_count += 1
      #                @correction_span  += pending_count
      #                pending_count = 0
      #                start_at = context.sequence_number
      #             else
      #                break
      #             end
      #          end
      # 
      #          context = context.context
      #       end
      #    end
      # 
      #    # return ((@correction_count + (@correction_count - 1) / @correction_span) * 20).ceil
      #    if end_at - start_at == 0 then
      #       return @correction_count
      #    else
      #       return ((@correction_count / (end_at - start_at)) * 20).ceil
      #    end
      # end
      # 
      # 
      # #
      # # ::reduce_distance()
      # #  - reduces a distance to a "relative size" as follows:
      # #      0     - 0
      # #      1-2   - 1
      # #      3-5   - 2
      # #      6-9   - 3
      # #      10-14 - 4
      # #      15+   - 5
      # 
      # def self.reduce_distance( distance )
      #    if distance.nil? then
      #       return 0
      #    elsif distance <= 0 then
      #       return 0
      #    elsif true then
      #       return distance
      # 
      # 
      # 
      #    elsif distance < 3 then
      #       return 1
      #    elsif distance < 6 then
      #       return 2
      #    elsif distance < 10 then
      #       return 3
      #    elsif distance < 15 then
      #       return 4
      #    else
      #       return 5
      #    end
      # end




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





   end # PositionMarker



end  # module PositionMarkers
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/position_markers/start_position.rb"
require "#{$RCCLIB}/interpreter/position_markers/attempt_position.rb"
