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
require "#{$RCCLIB}/interpreter/correction.rb"

module RCC
module Interpreter

 
 #============================================================================================================================
 # class Situation
 #  - holds the core state information for the Parser (node stack, state stack, error data, etc.) and provides useful 
 #    services thereupon

   class Situation

    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :stack                # a stack of StackFrames, representing our current state
      attr_reader   :token_stream         # the TokenStream from whence we get our Tokens
      attr_reader   :solution             # the CSN/ASN produced by Accept
      attr_accessor :error                # the Error recording where our parse failed
      attr_reader   :attempts             # if we hit an Attempt, a list of Situations that take over from us
                                          
      attr_reader   :context_correction   # if we were created to run an error recovery, this is the Correction that owns us
      attr_reader   :corrections          # the Corrections we created to recover from @error
      
      def initialize( token_stream, context_or_start_state, expected_productions = nil, context_correction = nil ) 
         
         #
         # Core state
         
         @token_stream        = token_stream
         @solution            = nil         
         @error               = nil         
         @attempts            = []                    
         @context_correction  = context_correction

         if context_or_start_state.is_a?(Situation) then
            @context = context_or_start_state
            @stack   = @context.stack.dup
         else        
            @context = nil
            @stack   = [ StackFrame.new(nil, context_or_start_state) ]
         end


         #
         # If started by an Attempt, our context is expecting us to reduce past our start point using some
         # specific Productions.  If so, this is the list.
         
         @expected_productions = expected_productions
         if expected_productions.nil? then
            @checked   = true                   # If not checking, we'll consider ourselves already checked
            @committed = true                   # If not checking, we'll consider our parse already committed
         else
            @checked   = false                  # Set true once we've found the reduce we care about
            @check_at  = @stack.length          # We'll check the first time we reduce past this point in the stack
            @committed = false                  # Set true once we've found a reduce from the expected_productions at the right point
         end


         #
         # Error correction support.
         
         @pending_corrections = []          
         @corrections         = []

      end
      
      def error_count()
         if @context.nil? then
            return (@error.nil? ? 0 : 1)
         else
            return @context.error_count + (@error.nil? ? 0 : 1)
         end
      end
      
      
      #
      # accepted?()
      #  - returns true if this Situation has been accept()ed
      
      def accepted?()
         return @solution.exists?
      end
      
      
      #
      # failed?()
      #  - returns true if this Situation has encountered an error
      
      def failed?()
         return @error.exists?
      end
      
      
      #
      # corrected?()
      #  - returns true if we had an Error but found successful Corrections
      
      def corrected?()
         return !@corrections.empty?
      end
      
      
      #
      # committed?()
      #  - returns true if our expected Productions have been met 
      
      def committed?()
         return @committed 
      end
      
      
      #
      # describe()
      #  - generates a pretty-printed description of the stack and lookahead

      def display( indent, state = nil, next_token = nil )
         state, next_token = look_ahead() if state.nil? 
         
         stack_description = @stack.collect{|frame| frame.node.description}.join( ", " )
         stack_bar         = "=" * (stack_description.length + 9)

         STDOUT.puts "#{indent}"
         STDOUT.puts "#{indent}"
         STDOUT.puts "#{indent}#{stack_bar}"
         STDOUT.puts "#{indent}STACK: #{stack_description} |      LOOKAHEAD: #{next_token.description} at #{next_token.line_number}:#{next_token.column_number}, position #{next_token.sequence_number}:#{next_token.start_position}"
         STDOUT.puts "#{indent}#{stack_bar}"
         state.display( STDOUT, "#{indent}| " )
      end
      
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # Error Correction
    #---------------------------------------------------------------------------------------------------------------------


      #
      # mark_unexpected_end_of_source()
      #  - adds an error that indicates an unexpected end of the token stream
      
      def mark_unexpected_end_of_source( eof_token, expected_types, explain_indent = nil )
         expected_tokens = tokenize_types( expected_types )
         
         STDOUT.puts "#{explain_indent}===> UNEXPECTED END OF FILE; expected (one of): #{Token.description(expected_tokens)}" unless explain_indent.nil?
         return set_error( eof_token, expected_tokens )
      end
      
      
      #
      # mark_unexpected_token()
      #  - adds an error that indicates an unexpected token
      
      def mark_unexpected_token( bad_token, expected_types, explain_indent = nil )
         expected_tokens = tokenize_types( expected_types )
         
         STDOUT.puts "#{explain_indent}===> ERROR: unexpected token: #{bad_token}; expected (one of): #{Token.description(expected_tokens)}" unless explain_indent.nil?
         return set_error( bad_token, expected_tokens )
      end
      
      
      #
      # accept_correction()
      #  - moves a Correction from the untried_corrections list to the accepted_corrections list
      #  - sends the message up the context chain
      
      def accept_correction( correction )
         
         #
         # When we pass the message up the chain, we don't know what Correction was used to link us to the context 
         # Situation.  So we pass ourself instead, and let the context search for the right Correction.

         correction = find_pending_correction_by_situation(correction) if correction.is_a?(Situation)
         
         #
         # If the Correction is on the pending_corrections list, move it to the accepted list.  Regardless,
         # mark corrected and send the message up the chain.
         
         unless correction.nil?
            @corrections << correction
            @pending_corrections.delete( correction )
         end
         
         @context.accept_correction( self ) unless @context.nil?
      end
      
      
      #
      # discard_correction()
      #  - discards a Correction from the pending_corrections list, if it has failed
      #  - sends the message up the context chain
   
      def discard_correction( correction )

         #
         # When we pass the message up the chain, we don't know what Correction was used to link us to the context 
         # Situation.  So we pass ourself instead, and let the context search for the right Correction.
         
         if correction.is_a?(Situation) then
            correction = find_pending_correction_by_situation(correction)
         end

         #
         # We assume our caller knew what e was talking about, so we do the discard if possible.  We then
         # check if we have failed to correct.  If so, we must ask our context to discard us, too.

         unless correction.nil?
            @pending_corrections.delete( correction )
            if !corrected?() and @pending_corrections.empty? then
               @context.discard_correction( self )
            end
         end
      end
      
      
      #
      # correct()
      #  - creates a Correction from this one with the supplied insertion and delete tokens
      #  - be sure to set the TokenStream the way you want it before calling
      #  - adds the Correction to the pending_correction list
      
      def correct( insertion_token, deletion_token, context_correction )
         correction = Correction.new( insertion_token, deletion_token, self, context_correction )
         @pending_corrections << correction
         
         return correction
      end
      
      
      
      #
      # discard()
      #  - discards this Situation from our context Situation's attempt list
      
      def discard()
         unless @context.nil?
            @context.attempts.delete( self )
         end
      end
      
      
      
   



    #---------------------------------------------------------------------------------------------------------------------
    # Duplication Services
    #---------------------------------------------------------------------------------------------------------------------
    

      #
      # cover_for_attempt()
      #  - returns a new Situation you can use to process an Attempt
      
      def cover_for_attempt( expected_productions )
         return Situation.new( @token_stream, self, expected_productions )
      end
      
      
      #
      # take_solution_from()
      #  - copies another Situation's data into this one
      
      def take_solution_from( other )
         @token_stream = other.token_stream
         @solution     = other.solution
         @corrections  = other.corrections
      end
      
      

      
      

    #---------------------------------------------------------------------------------------------------------------------
    # TokenStream Support
    #---------------------------------------------------------------------------------------------------------------------

    
      #
      # look_ahead()
      
      def look_ahead( state = nil, explain_indent = nil, relative_token = nil )
         state = @stack[-1].state if state.nil?
         next_token = la( state, explain_indent, relative_token )
         return state, next_token, next_token.type
      end
      
      
      #
      # la()
      #  - like look_ahead(), but only returns the Token
      
      def la( state = nil, explain_indent = nil, relative_token = nil )
         state = @stack[-1].state if state.nil?

         unless explain_indent.nil?
            lexer_explanation = "Lexing with prioritized symbols: #{state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"
            
            STDOUT.puts "#{explain_indent}"
            STDOUT.puts "#{explain_indent}"
            STDOUT.puts "#{explain_indent}" + "-" * lexer_explanation.length 
            STDOUT.puts "#{explain_indent}#{lexer_explanation}" 
         end
         
         if relative_token.nil? then
            return @token_stream.peek( state.lexer_plan, explain_indent )
         else
            return @token_stream.peek_after( relative_token, state.lexer_plan, explain_indent )
         end
      end
      
      
      #
      # consume()
   
      def consume( state = nil, explain_indent = nil )
         state = @stack[-1].stack if state.nil?
         return @token_stream.read( state.lexer_plan, explain_indent )
      end
    
    
      #
      # position_before()
      
      def position_before( token )
         @token_stream.position_before( token )
      end
      
      
      #
      # position_after()
      
      
      def position_after( token )
         @token_stream.position_after( token )
      end
      

      #
      # fake_token()
      
      def fake_token( type, at_token = nil )
         @token_stream.fake_token( type, at_token )
      end
      
    
      #
      # restart()
      
      def restart()
         @token_stream.restart()
      end
      
      
      
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Stack Processing
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # shift()
      #  - shifts a node onto the node stack and updates the state stack
      
      def shift( node, to_state, explain_indent = nil )
         STDOUT.puts "#{explain_indent}===> SHIFT #{node.description} AND GOTO #{to_state.number}" unless explain_indent.nil?
         
         @stack << StackFrame.new( node, to_state )
         
         return true
      end
      
      
      #
      # reduce()
      #  - reduces nodes from the top of the stack by a production
      #  - returns false if there was a problem (you tried to reduce by an invalid production)
      
      def reduce( production, build_ast, explain_indent = nil )
         count = production.symbols.length 

         #
         # If we are validating the production by which we reduce past our start point, check it now.
         
         if !@checked and (@stack.length - count) < @check_at then
            @checked = true
            unless @expected_productions.member?( production ) 
               STDOUT.puts "#{explain_indent}===> REDUCE #{production.to_s} INVALID; RETURNING" unless explain_indent.nil?
               @committed = false
               return false
            else
               @committed = true
            end
         end
         
         #
         # Pop the nodes from our stacks.
         
         STDOUT.puts "#{explain_indent}===> REDUCE #{production.to_s}" unless explain_indent.nil?
         
         frames = @stack.slice!( -count..-1 )
         nodes  = frames.collect{ |frame| frame.node }
      
         #
         # Get the goto state from the now-top-of-stack State: it will be the next state.
      
         state = @stack[-1].state
         goto_state = state.transitions[production.name]
         
         STDOUT.puts "#{explain_indent}===> PUSH AND GOTO #{goto_state.number}" unless explain_indent.nil?
   
         node = ( build_ast ? ASN.new(production, nodes[0].first_token, nodes) : CSN.new(production.name, nodes) )
         @stack << StackFrame.new( node, goto_state )
         
         return true
      end
      

      
      #
      # accept()
      #  - accepts the top node as a solution to this ParseState
      
      def accept( explain_indent = nil )
         STDOUT.puts "#{explain_indent}===> ACCEPT" unless explain_indent.nil?         
         @solution = stack[-1].node
         
         return true
      end
      
      
      #
      # unwind()
      #  - unwinds the Situation, calling your block once for each
      #  - passes in the current top state and rewinds the lookahead to where it was at the time
      #  - note that you are essentially destroying the Situation by calling this
      
      def unwind()
         tokens_popped = 0
         
         until @stack.length == 0
            yield( @stack[-1].state, tokens_popped )
            
            if @stack.length == 1 then
               break    # When we reach the start frame, we're done
            else
               popped_frame  = @stack.pop
               tokens_popped = popped_frame.node.token_count
               @token_stream.position_before( popped_frame.node.first_token )
            end
         end
      end
      
      


      

    #---------------------------------------------------------------------------------------------------------------------
    # Internal stuff
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      #
      # set_error()
      #  - sets the error for this Situation, effectively marking it done
      
      def add_error( bad_token, expected_tokens )
         error = Error.new( bad_token, expected_tokens )
         @error = error
         return error
      end


      #
      # tokenize_types()
      #  - returns a list of fake Tokens for the specified types
      
      def tokenize_types( types )
         return types.collect{|t| @token_stream.fake_token(type)}
      end


      #
      # find_pending_correction_by_situation()
      #  - searches the @pending_correction list for a correction with the specified Situation
      
      def find_pending_correction_by_situation( situation )
         correction = nil
         @pending_corrections.each do |pending_correction|
            if pending_correction.situation.object_id == situation.object_id then
               correction = pending_correction
               break
            end
         end
         
         return correction
      end
      
      
      
   end # Situation
   


end  # module Interpreter
end  # module Rethink
