#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"
require "rcc/interpreter/token_stream.rb"
require "rcc/interpreter/csn.rb"
require "rcc/interpreter/asn.rb"


module RCC
module Interpreter

 
 #============================================================================================================================
 # class Parser
 #  - an interpretive Parser for a Grammar
 #  - useful for testing stuff out

   class Parser
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( parser_plan, token_stream, build_ast = true, max_error_depth = 3, repair_attempts = {} )
         @parser_plan          = parser_plan
         @token_stream         = token_stream
         @build_ast            = build_ast
         @node_stack           = nil
         @state_stack          = nil
         @require_check        = false
         @check_at             = 0
         @valid_productions    = nil
         @max_error_depth      = max_error_depth
         @error_depth          = 0
         @attempt_failed       = false
         @repair_attempts      = repair_attempts
      end
            

      #
      # parse()
      #  - applies the Grammar to the inputs and builds a generic AST
      
      def parse( explain = true, indent = "" )
         
         @node_stack  = []                              if @node_stack.nil?
         @state_stack = [ @parser_plan.state_table[0] ] if @state_stack.nil?
         

         #
         # Process actions until an ending is found.
         
         action = nil
         done   = false

         until done
            
            #
            # Get the state and lookahead.
            
            state, next_token, token_type = get_context( explain, indent )

            la_description = [1].collect{|i| t = la(i); t.nil? ? "$" : t.description}.join( ", " )
            describe_position( state, la_description, indent ) if explain

            #
            # Select the next action.
            
            action = state.actions[token_type]
            
            if explain then
               STDOUT.puts "#{indent}| #{state.lookahead_explanations}"
               STDOUT.puts "#{indent}| Action analysis for lookahead #{la_description}"

               if state.explanations.nil? then
                  bug( "no explanations found" )
               else
                  state.explanations[token_type].each do |explanation|
                     explanation.to_s.split("\n").each do |line|
                        STDOUT << "#{indent}|    " << line.to_s << "\n"
                     end
                  end
               end
            end
                        
            #
            # Process the action.

            if !action.nil? then
               done = perform_action( action, next_token, token_type, explain, indent )
            else
               STDOUT.puts "#{indent}===> ERROR: unexpected token: #{next_token}" if explain

               if @error_depth > @max_error_depth then
                  STDOUT.puts "#{indent}===> REPAIR FAILED; RETURN" if explain
                  @attempt_failed = true
                  done            = true
               elsif next_token.nil?
                  STDOUT.puts "#{indent}===> UNEXPECTED END OF FILE" if explain
                  @attempt_failed = true
                  done            = true
               else
                  child_indent = "#{indent}   "
                  position     = next_token.start_position

                  repair_attempts = @repair_attempts
                  unless @repair_attempts.member?(position)
                     repair_attempts = { position => [] }
                     @repair_attempts.each do |repair_position, attempts|
                        repair_attempts[repair_position] = [] + attempts
                     end
                  end
                  
                  #
                  # First, try inserting each of our valid lookahead tokens and attempt a reparse from the current state.

                  state.actions.keys.each do |follow_type|
                     unless follow_type.nil? or repair_attempts[position].member?(follow_type)
                        repair_attempts[position] << follow_type
                        
                        insert_token = Token.new( follow_type.is_a?(String) ? follow_type : "" )
                        insert_token.locate( position, next_token.line_number, next_token.column_number, next_token.source_descriptor, follow_type )

                        STDOUT.puts "#{indent}===> INSERT #{insert_token.description} AND RETRY" if explain

                        recovery_parser = Parser.new( @parser_plan, @token_stream.cover( [insert_token] ), @build_ast, @max_error_depth, @repair_attempts )
                        if node = recovery_parser.parse_from_error( @node_stack, @state_stack, repair_attempts, @error_depth + 1, explain, child_indent ) then
                           @node_stack = [node]
                           done        = true
                           break
                        else
                           rewind( next_token )
                        end
                     end
                  end

                  #
                  # If we were unable to recover, try discarding tokens next.

                  unless done
                     # follow_tokens = [la(2), la(3), la(4)]
                     # follow_tokens.each do |follow_token|
                     #    follow_type  = follow_token.nil? ? nil : follow_token.type
                     #    if state.actions.member?(follow_type) then
                     #       
                     #    end
                     # end
                  end
               end
            end
                  
         end
         
         return @attempt_failed ? nil : @node_stack[-1]
      end
      




    #---------------------------------------------------------------------------------------------------------------------
    # Mid-level Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    protected

      
      #
      # get_context()
      #  - returns the current State, lookahead token, and lookahead token type
      
      def get_context( explain = false, indent = "" )
         state = @state_stack[-1]
         set_lexer_plan( state.lexer_plan )
         
         if explain then
            lexer_explanation = "Lexing with prioritized symbols: #{state.lookahead.collect{|symbol| Plan::Symbol.describe(symbol)}.join(" ")}"
            
            STDOUT.puts "#{indent}"
            STDOUT.puts "#{indent}"
            STDOUT.puts "#{indent}" + "-" * lexer_explanation.length 
            STDOUT.puts "#{indent}#{lexer_explanation}" 
         end
         
         next_token = la(1, explain, indent)
         token_type = (next_token.nil? ? nil : next_token.type)
         
         return state, next_token, token_type
      end
    

      #
      # describe_position()
      #  - generates a pretty-printed description of the stack and lookahead
      
      def describe_position( state, la_description, indent )
         stack_description = @node_stack.collect{|node| node.description}.join( ", " )
         stack_bar         = "=" * (stack_description.length + 9)

         STDOUT.puts "#{indent}"
         STDOUT.puts "#{indent}"
         STDOUT.puts "#{indent}#{stack_bar}"
         STDOUT.puts "#{indent}STACK: #{stack_description} |      LOOKAHEAD: #{la_description}"
         STDOUT.puts "#{indent}#{stack_bar}"
         state.display( STDOUT, "#{indent}| " )
      end
      
      
      #
      # perform_action()
      #  - performs a single action against the current Parser state
      
      def perform_action( action, next_token, token_type, explain, indent )
         done = false
         
         case action

            when Plan::Actions::Shift
               STDOUT.puts "#{indent}===> SHIFT #{next_token.description} AND GOTO #{action.to_state.number}" if explain

               @node_stack  << consume()
               @state_stack << action.to_state
               
               
            when Plan::Actions::Reduce
               production = action.by_production
               count      = production.symbols.length
               
               #
               # If we are supposed to check this reduction against a list of valid Productions, do so now.
               
               if @require_check and (@node_stack.length - count) < @check_at then
                  @require_check = false
                  unless @valid_productions.member?( production ) 
                     if explain then
                        STDOUT.puts "#{indent}===> REDUCE #{action.by_production.to_s} INVALID; RETURNING"
                     end
                     @attempt_failed = true
                     done = true
                  end
               end
               
               unless done
                  
                  #
                  # First, collect enough nodes off the top of the stack to fill the CST.  Note also
                  # that we must discard any states that were pending for those nodes.
               
                  if explain then
                     STDOUT.puts "#{indent}===> REDUCE #{action.by_production.to_s}"
                  end

                  nodes = @node_stack.slice!(  -count..-1 )
                          @state_stack.slice!( -count..-1 )
               
                  node = nil
                  if @build_ast then
                     node = ASN.new( production, nodes )
                  else
                     node = CSN.new( production.name, nodes )
                  end
               
                  #
                  # Get the goto state from the now-top-of-stack State: it will be the next state.
               
                  state = @state_stack[-1]
                  goto_state = state.transitions[production.name]
                  STDOUT.puts "#{indent}===> PUSH AND GOTO #{goto_state.number}" if explain
            
                  @node_stack  << node
                  @state_stack << goto_state
               end
               
            when Plan::Actions::Accept
               STDOUT.puts "#{indent}===> ACCEPT" if explain
               done = true
               
            when Plan::Actions::Attempt
               first = true
               child_indent = "#{indent}   "
               
               action.actions.each do |attempt_action|
                  if explain then
                     if first then
                        first = false
                     else
                        STDOUT.puts "#{indent}" 
                        STDOUT.puts "#{indent}" 
                        STDOUT.puts "#{indent}<=== RETURN"
                     end

                     STDOUT.puts "#{indent}" 
                     STDOUT.puts "#{indent}" 
                     describe_position( @state_stack[-1], [1].collect{|i| t = la(i); t.nil? ? "$" : t.description}.join( ", " ), indent ) if explain
                     STDOUT.puts "#{indent}===> ATTEMPT #{attempt_action.to_s}"
                  end
                  
                  attempt_parser = Parser.new( @parser_plan, @token_stream, @build_ast, @max_error_depth, @repair_attempts )
                  if node = attempt_parser.parse_from_starting_point( @node_stack, @state_stack, attempt_action, explain, child_indent ) then
                     @node_stack = [node]
                     done        = true
                     break
                  else
                     rewind( next_token )
                  end
               end
            
            else
               nyi "support for #{action.class.name}"
         end
         
         return done
      end

      
      #
      # parse_from_starting_point()
      #  - runs a parse() that has a specified starting point
      #  - generally run on a child parser as the result of an Attempt action

      def parse_from_starting_point( node_stack, state_stack, start_action, explain = true, indent = "" )
         @node_stack  = node_stack.dup
         @state_stack = state_stack.dup
         
         #
         # If we are starting from a Shift, we are meant to Attempt only certain Productions, possibly of a larger set
         # that would be valid in other contexts.  This means we'll need to check the first time we try to reduce 
         # past our start point that the Production used is one of the valid set.  Set up the test.

         if start_action.is_a?(Plan::Actions::Shift) then
            @require_check     = true
            @check_at          = @node_stack.length
            @valid_productions = start_action.valid_productions
         end
         
         unless start_action.nil?
            STDOUT.puts "#{indent}| Attempting: #{start_action.to_s}" if explain
            state, next_token, token_type = get_context()
            perform_action( start_action, next_token, token_type, explain, indent ) 
         end
         
         return parse( explain, indent )
      end
      
      
      #
      # parse_from_error()
      #  - runs a parse() that has a specified start point
      #  - generally run on a child parser as the result of an error
      
      def parse_from_error( node_stack, state_stack, repair_attempts, error_depth, explain = true, indent = "" )
         @node_stack      = node_stack.dup
         @state_stack     = state_stack.dup
         @error_depth     = error_depth
         @repair_attempts = repair_attempts
         
         return parse( explain, indent )
      end
      
      
      
         




    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Low-level Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
    
      #
      # rewind()
      #  - rewinds the lexer to where it was when it produced the specified token
      
      def rewind( before_token )
         @token_stream.rewind( before_token )
      end
      
      
      #
      # set_lexer_plan()
      #  - swaps in a new LexerPlan for use with la() and consume()
      #  - takes the appropriate action to ensure the next token is from that new plan
      #  - doesn't do unecessary work
      
      def set_lexer_plan( plan )
         @token_stream.lexer_plan = plan
      end
    
          
      #
      # la()
      #  - looks ahead one or more tokens
      
      def la( count = 1, explain = false, indent = "" )
         return @token_stream.la( count, explain, indent )
      end
      
      
      #
      # consume()
      #  - shifts the next token off the lookahead and returns it
      
      def consume( explain = false, indent = "" )
         return @token_stream.consume( explain, indent )
      end
      
      
      
      #
      # expect_state()
      #  - raises an exception if the state is nil
      #  - returns the state
      
      def expect_state( state, message )
         raise message if state.nil?
         return state
      end
      
      
   end # Parser
   
   
   
   


end  # module Interpreter
end  # module Rethink
