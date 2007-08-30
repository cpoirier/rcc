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

      attr_reader   :node_stack
      attr_reader   :state_stack
      attr_reader   :solution
      attr_accessor :error
      attr_reader   :pending_corrections
      attr_reader   :corrections
      attr_reader   :context_correction
      attr_reader   :token_stream
      attr_reader   :attempts
      attr_accessor :recovery_stop
      
      def initialize( token_stream, context_or_start_state, expected_productions = nil, context_correction = nil ) 
         @token_stream        = token_stream
         @solution            = nil
         @stop_node           = nil
         @error               = nil
         @pending_corrections = []
         @corrections         = []
         @attempts            = [] 
         @context_correction  = context_correction

         if context_or_start_state.is_a?(Situation) then
            @context       = context_or_start_state
            @node_stack    = @context.node_stack.dup
            @state_stack   = @context.state_stack.dup
            @recovery_stop = @context.recovery_stop
         else
            @context       = nil
            @node_stack    = []
            @state_stack   = [ context_or_start_state ]
            @recovery_stop = 0
         end
         
         bug "WTF?" if @recovery_stop == 0 and !@context.nil?
         
         @expected_productions = expected_productions
         if expected_productions.nil? then
            @checked   = true
            @committed = true
         else
            @checked   = false
            @check_at  = @node_stack.length
            @committed = false
         end
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
         return !@solution.nil?
      end
      
      
      #
      # failed?()
      #  - returns true if this Situation has encountered an error
      
      def failed?()
         return !@error.nil?
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
         
         stack_description = @node_stack.collect{|node| node.description}.join( ", " )
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
         return add_error( eof_token, expected_tokens )
      end
      
      
      #
      # mark_unexpected_token()
      #  - adds an error that indicates an unexpected token
      
      def mark_unexpected_token( bad_token, expected_types, explain_indent = nil )
         expected_tokens = tokenize_types( expected_types )
         
         STDOUT.puts "#{explain_indent}===> ERROR: unexpected token: #{bad_token}; expected (one of): #{Token.description(expected_tokens)}" unless explain_indent.nil?
         return add_error( bad_token, expected_tokens )
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
      
      def correct( insertion_token, deletion_token, context_correction, recovery_stop )
         correction = Correction.new( insertion_token, deletion_token, self, context_correction )
         correction.situation.recovery_stop = recovery_stop
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
         state = @state_stack[-1] if state.nil?
         next_token = la( state, explain_indent, relative_token )
         return state, next_token, next_token.type
      end
      
      
      #
      # la()
      #  - like look_ahead(), but only returns the Token
      
      def la( state = nil, explain_indent = nil, relative_token = nil )
         state = @state_stack[-1] if state.nil?

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
         state = @state_stack[-1] if state.nil?
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
         
         @node_stack  << node      
         @state_stack << to_state
         
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
         
         if !@checked and (@node_stack.length - count) < @check_at then
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
         
         nodes = @node_stack.slice!(  -count..-1 )
                 @state_stack.slice!( -count..-1 )
      
         #
         # Get the goto state from the now-top-of-stack State: it will be the next state.
      
         state = @state_stack[-1]
         goto_state = state.transitions[production.name]
         
         STDOUT.puts "#{explain_indent}===> PUSH AND GOTO #{goto_state.number}" unless explain_indent.nil?
   
         @node_stack  << (build_ast ? ASN.new(production, nodes[0].first_token, nodes) : CSN.new(production.name, nodes) )
         @state_stack << goto_state
         
         return true
      end
      

      
      #
      # accept()
      #  - accepts the top node as a solution to this ParseState
      
      def accept( explain_indent = nil )
         STDOUT.puts "#{explain_indent}===> ACCEPT" unless explain_indent.nil?         
         @solution = node_stack[-1]
         
         return true
      end
      
      
      #
      # unwind()
      #  - unwinds the Situation, calling your block once for each
      #  - passes in the current top state and rewinds the lookahead to where it was at the time
      #  - note that you are essentially destroying the Situation by calling this
      
      def unwind()
         popped_node = nil
         tokens_popped = 0
         until @node_stack.empty?
            @token_stream.position_before( popped_node.first_token ) unless popped_node.nil?
            yield( @state_stack[-1], tokens_popped )
            
            @state_stack.pop
            popped_node    = @node_stack.pop
            tokens_popped += popped_node.token_count
         end
      end
      
      


      

    #---------------------------------------------------------------------------------------------------------------------
    # Internal stuff
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      #
      # add_error()
      #  - adds an error to the situation
      
      def add_error( bad_token, expected_tokens )
         error = Error.new( bad_token, expected_tokens )
         @local_errors << error
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
