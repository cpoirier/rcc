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
      attr_reader   :corrections
      attr_reader   :token_stream
      
      def initialize( token_stream, context_or_start_state, expected_productions = nil )
         @token_stream = token_stream
         @solution     = nil
         @stop_node    = nil
         @error        = nil
         
         if context_or_start_state.is_a?(Situation) then
            @node_stack  = context_or_start_state.node_stack.dup
            @state_stack = context_or_start_state.state_stack.dup
            @corrections = context_or_start_state.corrections
         else
            @node_stack  = []
            @state_stack = [ context_or_start_state ]
            @corrections = []
         end
         
         @expected_productions = expected_productions
         if expected_productions.nil? then
            @checked = true
         else
            @checked  = false
            @check_at = @node_stack.length
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
      # describe()
      #  - generates a pretty-printed description of the stack and lookahead

      def display( indent, state = nil, next_token = nil )
         if state.nil? then
            state, next_token = look_ahead()
         end
         
         stack_description = @node_stack.collect{|node| node.description}.join( ", " )
         stack_bar         = "=" * (stack_description.length + 9)

         STDOUT.puts "#{indent}"
         STDOUT.puts "#{indent}"
         STDOUT.puts "#{indent}#{stack_bar}"
         STDOUT.puts "#{indent}STACK: #{stack_description} |      LOOKAHEAD: #{next_token.description} at #{next_token.line_number}:#{next_token.column_number}, position #{next_token.start_position}"
         STDOUT.puts "#{indent}#{stack_bar}"
         state.display( STDOUT, "#{indent}| " )
      end
      
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # Error Reporting
    #---------------------------------------------------------------------------------------------------------------------


      #
      # mark_unexpected_end_of_source()
      #  - adds an error that indicates an unexpected end of the token stream
      
      def mark_unexpected_end_of_source( eof_token, expected_types, explain = false, indent = "" )
         expected_tokens = tokenize_types( expected_types )
         
         STDOUT.puts "#{indent}===> UNEXPECTED END OF FILE; expected (one of): #{Token.description(expected_tokens)}" if explain
         return add_error( eof_token, expected_tokens )
      end
      
      
      #
      # mark_unexpected_token()
      #  - adds an error that indicates an unexpected token
      
      def mark_unexpected_token( bad_token, expected_types, explain = false, indent = "" )
         expected_tokens = tokenize_types( expected_types )
         
         STDOUT.puts "#{indent}===> ERROR: unexpected token: #{bad_token}; expected (one of): #{Token.description(expected_tokens)}" if explain
         return add_error( bad_token, expected_tokens )
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
      #  - returns the current State, lookahead token, and lookahead token type
      
      def look_ahead( state = nil, explain = false, indent = "" )
         state = @state_stack[-1] if state.nil?
         next_token = la( 1, state, explain, indent )
         return state, next_token, next_token.type
      end
      
      
      #
      # la()
      #  - like look_ahead(), but only returns the Token
      
      def la( count = 1, state = nil, explain = false, indent = "" )
         @token_stream.lexer_plan = state.lexer_plan
         
         if explain then
            lexer_explanation = "Lexing with prioritized symbols: #{state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"
            
            STDOUT.puts "#{indent}"
            STDOUT.puts "#{indent}"
            STDOUT.puts "#{indent}" + "-" * lexer_explanation.length 
            STDOUT.puts "#{indent}#{lexer_explanation}" 
         end
         
         return @token_stream.la(count, explain, indent)
      end
    
    
      #
      # rewind()
      #  - rewinds the TokenStream to where it was before reading the specified Token
      
      def rewind( token )
         @token_stream.rewind( token )
         @token_stream.lexer_plan = @state_stack[-1].lexer_plan
      end

      
      
    
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Stack Processing
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # shift()
      #  - shifts a node onto the node stack and updates the state stack
      
      def shift( node, to_state, explain = false, indent = "" )
         STDOUT.puts "#{indent}===> SHIFT #{node.description} AND GOTO #{to_state.number}" if explain
         
         @node_stack  << node      
         @state_stack << to_state
         
         return true
      end
      
      
      #
      # reduce()
      #  - reduces nodes from the top of the stack by a production
      #  - returns false if there was a problem (you tried to reduce by an invalid production)
      
      def reduce( production, build_ast, explain = false, indent = "" )
         count = production.symbols.length 

         #
         # If we are validating the production by which we reduce past our start point, check it now.
         
         if !@checked and (@node_stack.length - count) < @check_at then
            @checked = true
            unless @expected_productions.member?( production ) 
               STDOUT.puts "#{indent}===> REDUCE #{production.to_s} INVALID; RETURNING" if explain
               return false
            end
         end
         
         #
         # Pop the nodes from our stacks.
         
         STDOUT.puts "#{indent}===> REDUCE #{production.to_s}" if explain
         
         nodes = @node_stack.slice!(  -count..-1 )
                 @state_stack.slice!( -count..-1 )
      
         #
         # Get the goto state from the now-top-of-stack State: it will be the next state.
      
         state = @state_stack[-1]
         goto_state = state.transitions[production.name]
         
         STDOUT.puts "#{indent}===> PUSH AND GOTO #{goto_state.number}" if explain
   
         @node_stack  << (build_ast ? ASN.new(production, nodes[0].first_token, nodes) : CSN.new(production.name, nodes) )
         @state_stack << goto_state
         
         return true
      end
      

      
      #
      # accept()
      #  - accepts the top node as a solution to this ParseState
      
      def accept( explain = false, indent = "" )
         STDOUT.puts "#{indent}===> ACCEPT" if explain         
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
         until @node_stack.empty?
            @token_stream.rewind( popped_node.first_token ) unless popped_node.nil?
            yield( @state_stack[-1] )
            
            @state_stack.pop
            popped_node = @node_stack.pop
         end
      end
      
      
      #
      # correct()
      #  - creates a Correction from this one with the supplied insertion and delete tokens
      #  - be sure to set the TokenStream the way you want it before calling
      
      def correct( insertion_token, deletion_token )
         return Correction.new( insertion_token, deletion_token, self )
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
      
      
   end # Situation
   


end  # module Interpreter
end  # module Rethink
