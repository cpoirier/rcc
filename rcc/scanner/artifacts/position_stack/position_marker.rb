#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/scanner/artifacts/correction.rb"
require "#{$RCCLIB}/scanner/artifacts/node.rb"

module RCC
module Scanner
module Artifacts
module PositionStack

 
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
      attr_accessor :sequence_number
      attr_accessor :branch_info
      attr_reader   :position_registry
      attr_reader   :original_stream_position
      attr_accessor :adjusted_stream_position
      attr_accessor :determinant
      
      alias stream_position adjusted_stream_position
      
      def initialize( context, node, state, source, stream_position, recovery_registry = nil, determinant = nil )
         @context         = context
         @node            = node
         @state           = state
         @signature       = nil
         @sequence_number = (@context.nil? ? 0 : @context.sequence_number + 1)
         
         #
         # Token management

         @source                   = source
         @original_stream_position = stream_position
         @adjusted_stream_position = stream_position
         @determinant              = determinant
         
         #
         # Register the Position with any recovery context.  This may raise Parser::PositionSeen.
         
         if !recovery_registry.nil? then
            @recovery_registry = recovery_registry
            mark_recovery_progress( self )
         end
         
         @corrections_cost = @context.nil? ? 0 : @context.corrections_cost(false) + node.corrections_cost
      end
      
      
      def start_position?()
         return false
      end
      
      
      #
      # determinant()
      #  - returns the next token or next character, depending on which is available
      #  - returns nil if no determinant would normally be used by the position
      
      def determinant()
         if @determinant.nil? then
            unless @state.context_free?
               if @source.at_eof?(@adjusted_stream_position) then
                  @determinant = Scanner::Artifacts::Nodes::Token.end_of_file( @adjusted_stream_position, @source.eof_line_number, @source.eof_column_number, @source )
               else
                  @determinant = Scanner::Artifacts::Nodes::Character.new(nil, @adjusted_stream_position, @source)
               end
            end
         end
         
         return @determinant 
      end
      
      
      def stream_position=( position )
         @determinant = nil
         @adjusted_stream_position = position
      end
      
      
      def branch_root?( position )
         return false if @branch_info.nil?
         return @branch_info.root_position.object_id == position.object_id
      end
      
      
      def branch_id( default = nil )
         return default if @branch_info.nil?
         return @branch_info.id
      end


      def committable?()
         return false if @branch_info.nil?
         return @branch_info.committable?(self)
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
         
         #
         # Figure out the stream position past which we should not correct.  
         
         unwind_limit = -1
         last_correction = last_correction()
         unless last_correction.nil?
            unwind_limit = last_correction.unwind_limit
         end
         
         #
         # Call the block until we run out of positions.
         
         position = self
         until position.nil?
            break if position.stream_position < unwind_limit
            break if position.stream_position == unwind_limit and last_correction.deletes_token?
            break if position.determinant.corrected?
            
            # position.next_token.rewind_position < corrected? or (position.node.exists? and position.node.corrected?)
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
      # allocate_recovery_registry()
      #  - returns the current recovery_registry or an empty one
      
      def allocate_recovery_registry()
         if @recovery_registry.nil? then
            return {}
         else
            return @recovery_registry 
         end
      end
      
      
      #
      # corrections_cost()
      #  - returns the combined corrections cost of this position's node and next_token
      
      def corrections_cost( include_next_token = true )
         if include_next_token and @next_token.exists? then
            return @corrections_cost + @next_token.corrections_cost
         else
            return @corrections_cost
         end
      end
      
      
      #
      # tainted?
      #  - returns true if our node or any context position's node is tainted
      
      def tainted?( include_next_token = true )
         if include_next_token then 
            return true if (@next_token.exists? and next_token().tainted?)
         end
         
         return true if @node.exists? and @node.tainted?
         return @context.tainted? if @context.exists?
         return false
      end


      #
      # recovered?
      #  - returns true if any preceding error has been recovered from
      #  - returns nil if there are no preceding errors
      
      def recovered?()
         last_correction = last_correction()
         return nil if last_correction.nil?

         error_position = last_correction.original_error_position
         each_position do |position|
            return true  if position.node.nil?
            return true  if position.node.recoverable?
            return false if position.node.tainted?
            return false if position.node.token? and position.node.start_position <= error_position
         end

         bug( "should this ever happen?" )
      end
      

      # #
      # # original_error_position
      # #  - returns the source position of closest original error still on the stack
      # 
      # def original_error_position()
      #    error_position = @stream_position
      #    each_position do |position|
      #       if position.node.tainted?() then
      #          error_position = position.node.last_correction.original_error_position
      #          break
      #       end
      #    end
      # 
      #    return error_position
      # end
      # 
      # 
      #
      # last_correction()
      #  - returns the last Correction from the stack and (optionally) next_token
      
      def last_correction( consider_lookahead = true )
         if consider_lookahead and @next_token.exists? and @next_token.corrected? then
            return @next_token.last_correction
         end
         
         each_position() do |position|
            return position.node.last_correction if position.node.exists? and position.node.corrected?
         end
         
         return nil
      end
      
      
      #
      # corrections()
      #  - returns all the Corrections
      
      def corrections( consider_lookahead = true )
         if @context.nil? then
            return (@node.nil? ? [] : @node.corrections()) + (consider_lookahead ? (@next_token.exists? and @next_token.corrections) : [])
         else
            return @context.corrections(false) + @node.corrections() + (consider_lookahead ? (@next_token.exists? and @next_token.corrections) : [])
         end
      end
      
      
      #
      # recovery_context
      #  - returns the recovery_context under which this Position was generated
      
      def recovery_context
         return nil unless tainted?
         return last_correction().recovery_context
      end
      
      
      
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------


      #
      # push()
      #  - creates a new Position that uses this as its context
      #  - returns the new Position
      #  - raises Parser::PositionSeen if you attempt to push() to a Position we've already been

      def push( node, state, reduce_position = nil, branch_point = nil )
         next_position = nil
         
         #
         # Decide on which (if any) recovery registry to pass on.  If the reduce_position had one, and the
         # new node is tainted, pass its registry on.  Otherwise, we pass on ours (if any).
         
         recovery_registry = nil
         if recovery_registry.exists? and recovery_registry.recovery_registry.exists? and node.tainted? then
            recovery_registry = reduce_position.recovery_registry
         else
            recovery_registry = @recovery_registry
         end
         
         #
         # Pass forward any faked lookahead, if we are reducing.

         warn_nyi( "faked lookahead stuff" )
         next_token = nil
         # if reduce_position.exists? and reduce_position.next_token.corrected? then
         #    next_token = reduce_position.next_token
         # end
         
         #
         # Generate the new position.  We patch up the sequence number if reducing, as it will be generated as 
         # following us, not the popped top-of-stack.
         
         next_position = PositionMarker.new( self, node, state, @source, node.follow_position, recovery_registry, next_token )
         next_position.adjust_sequence_number( reduce_position ) if reduce_position.exists?

         #
         # "Unread" any skipped data, if appropriate.
         #          
         # if restore_lookahead and reduce_position.exists? and next_token.nil? then
         #    next_position.stream_position = reduce_position.rewind_position 
         # end
         
         #
         # Return the new Position.

         return next_position
      end
      
      
      #
      # replace()
      #  - returns a new Position identical to this one, except for its determinant
      
      def replace( determinant, reduce_position = nil )
         next_position = PositionMarker.new( @context, @node, @state, @source, determinant.follow_position, @recovery_registry, determinant )
         next_position.adjust_sequence_number( reduce_position ) if reduce_position.exists?
         
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
      # correct_by_insertion()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead
      #  - pass in the recovery_registry if you want the position (and its followers) checked

      def correct_by_insertion( type, recovery_context )
         
         #
         # Create the token to insert.
         
         token = @lexer.fake( @stream_position, type, @rewind_position..(@stream_position-1) )
         token.taint( Artifacts::Corrections::Insertion.new(token, @stream_position, recovery_context) )

         # token = @lexer.fake( @stream_position, type )
         # token.rewind_position = @stream_position
                  
         #
         # Create the correction and a new Position to replace this one.  
         
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, recovery_context.allocate_recovery_registry, token )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end


      #
      # correct_by_replacement()
      #  - produces a new position similar to this one, but with a manufactured token on lookahead, in place of the next token
      #  - pass in the recovery_registry if you want the position (and its followers) checked

      def correct_by_replacement( type, recovery_context )
         
         #
         # Grab the copy of the token we are replacing and create the token to insert.
         
         replaced_token = next_token()
         token = @lexer.fake( @stream_position, type, @rewind_position..replaced_token.footprint.end )
         token.taint( Artifacts::Corrections::Replacement.new(token, replaced_token, @stream_position, recovery_context) )

         #
         # Create the correction and a new Position to replace this one.  

         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, @stream_position, recovery_context.allocate_recovery_registry, token )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end


      #
      # correct_by_deletion()
      #  - produces a new position similar to this one, but with the second next token on lookahead
      #  - pass in the recovery_registry if you want the position (and its followers) checked
      
      def correct_by_deletion( recovery_context, estream = nil )
         
         #
         # Re-arrange our lookahead.  We taint the new next Token to get the Correction in place,
         # then untaint it, as the Token is real.
         
         deleted_token = next_token( estream )
         token = next_token( estream, deleted_token.follow_position )
         token.taint( Artifacts::Corrections::Deletion.new(deleted_token, deleted_token.follow_position, recovery_context) )
         token.untaint()

         #
         # Create the correction and a new Position to replace this one.
         
         corrected_position = PositionMarker.new( @context, @node, @state, @lexer, deleted_token.follow_position, recovery_context.allocate_recovery_registry, token )
         corrected_position.sequence_number = @sequence_number

         return corrected_position
      end


      #
      # mark_recovery_progress()
      #  - when used as a recovery context, adds a progress Position to our registry
      #  - raises Parser::PositionSeen if the Position has already been tried during this recovery
      
      def mark_recovery_progress( position )
         progress_signature = position.recovery_signature()
          
         if @recovery_registry.member?(progress_signature) then
            # raise Parser::PositionSeen.new( position )
         else
            @recovery_registry[progress_signature] = true
         end
      end



      #
      # join_position()
      #  - joins an identical position to this one, to avoid duplication in continued parsing
      #  - generally used during error recovery
      
      def join_position( position )
         @joined_positions = [] unless defined?(@joined_positions)
         @joined_positions << position
      end
      
      
      #
      # joined_positions()
      #  - returns any joined positions
      
      def joined_positions()
         return [] unless defined?(@joined_positions)
         return @joined_positions
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
            return "#{@recovery_signature}|#{next_token().type.signature}"
         end
      end


      def signature( include_next_token = true )
         signature = nil
         
         if @context.nil? or @context.node.nil? then
            signature = @node.nil? ? "" : "#{@node.first_token.rewind_position}:#{@node.description}"
         else
            signature = @context.signature(false) + ", " + (@node.nil? ? "$" : "#{@node.first_token.rewind_position}:#{@node.description}")
         end

         if include_next_token then
            return "#{signature} | #{next_token().rewind_position}:#{next_token().description}"
         else
            return signature
         end
      end
      




    #---------------------------------------------------------------------------------------------------------------------
    # Output and representation
    #---------------------------------------------------------------------------------------------------------------------


      #
      # description()
      #  - return a description of this Position (node data only)

      def description( include_determinant = false )
         if @description.nil? then
            if @context.nil? or @context.node.nil? then
               @description = @node.nil? ? "" : "#{@sequence_number}:#{@node.description}#{@node.recoverable? ? " R" : (@node.tainted? ? " T" : "")}"
            else
               @description = @context.description + ", " + (@node.nil? ? "$" : "#{@sequence_number}:#{@node.description}#{@node.recoverable? ? " R" : (@node.tainted? ? " T" : "")}")
            end
         end

         if include_determinant then
            return "#{@description} | #{determinant().description}"
         else
            return @description
         end
      end



      #
      # display()

      def display( stream )
         stack_description = description()
         stack_label       = "STACK"
         stack_bar         = "=" * (stack_description.length + stack_label.length + 3)
         
         stream.puts "#{stack_bar}"
         stream.puts "#{stack_label} #{stack_description} |      LOOKAHEAD: #{lookahead_description()}   COST: #{corrections_cost()}"
         stream.puts "#{stack_bar}"
      end
      
      
      #
      # display_stack()
      
      def display_stack( stream )
         stack_description = description()
         stack_label       = "STACK"
         stack_bar         = "=" * (stack_description.length + stack_label.length + 3)

         stream.puts stack_bar
         stream.puts "#{stack_label} #{stack_description} |"
         stream.puts "#{stack_bar}"
      end
      
      
      #
      # display_lookahead()
      
      def display_lookahead( stream )
         stream.puts lookahead_description()
      end
      
      
      #
      # lookahead_description()
      
      def lookahead_description()
         if @state.context_free? then
            return "not checked in this state"
         else
            return "#{determinant.description}   #{determinant.line_number}:#{determinant.column_number}   positions #{determinant.start_position},#{determinant.follow_position}"
         end
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



end  # module PositionStack
end  # module Artifacts
end  # module Scanner
end  # module RCC


require "#{$RCCLIB}/scanner/artifacts/position_stack/start_position.rb"
require "#{$RCCLIB}/scanner/artifacts/position_stack/branch_info.rb"
