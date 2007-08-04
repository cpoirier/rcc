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

      def initialize( parser_plan, lexer, build_ast = true )
         @parser_plan = parser_plan
         @lexer       = lexer
         @lookahead   = []
         @build_ast   = build_ast
      end
      
      
      #
      # parse()
      #  - applies the Grammar to the inputs and builds a generic AST
      
      def parse( explain = false, start_state_number = 0 )
         
         start_state = @parser_plan.state_table[start_state_number]
         state_stack = [ start_state ]
         node_stack  = []
         action      = nil
         
         while true
            
            state = state_stack[-1]
            
            #
            # Determine our next action, based on lookahead.
            
            next_token = la()
            token_type = (next_token.nil? ? nil : next_token.type)
            action     = state.actions[token_type]
            
            if explain then
               stack_description = node_stack.collect{|node| node.description}.join( ", " )
               la_description    = [1].collect{|i| t = la(i); t.nil? ? "" : t.description}.join( ", " )
               stack_bar         = "=" * (stack_description.length + 9)

               STDOUT.puts ""
               STDOUT.puts ""
               STDOUT.puts stack_bar
               STDOUT.puts "STACK: #{stack_description} |      LOOKAHEAD: #{la_description}"
               STDOUT.puts stack_bar
               state.display( STDOUT, "| " )
            
               STDOUT.puts "| #{state.lookahead_explanations}"
               STDOUT.puts "| Action analysis for lookahead #{la_description} (#{state.actions[token_type].class.name})"
            
               if state.explanations.nil? then
                  bug( "no explanations found -- wtf?" )
               else
                  state.explanations[token_type].each do |explanation|
                     STDOUT << "|    " << explanation.to_s << "\n"
                  end
               end
            end
            
            
            #
            # Process the action.
            
            case action
               
               when Plan::Actions::Shift
                  STDOUT.puts "===> SHIFT #{next_token.description} AND GOTO #{action.to_state.state_number}" if explain

                  node_stack  << consume()
                  state_stack << action.to_state
                  
                  
               when Plan::Actions::Reduce
                  if explain
                     STDOUT.puts "===> REDUCE #{action.by_production.to_s}"
                  end
                  
                  production = action.by_production
                  
                  #
                  # First, collect enough nodes off the top of the stack to fill the CST.  Note also
                  # that we must discard any states that were pending for those nodes.
                  
                  nodes = []
                  production.symbols.length.times do 
                     nodes.unshift node_stack.pop
                     state_stack.pop
                  end
                  
                  csn = nil
                  if @build_ast then
                     csn = ASN.new( production, nodes )
                  else
                     csn = CSN.new( production.name, nodes )
                  end
                  
                  #
                  # Get the goto state from the now-top-of-stack State.  If there is no goto state,
                  # we have reached the end of the line.  BUG: is that right?
                  
                  state = state_stack[-1]
                  goto_state = state.transitions[production.name]
                  STDOUT.puts "===> PUSH AND GOTO #{goto_state.state_number}" if explain
               
                  node_stack  << csn
                  state_stack << goto_state
                  
               when Plan::Actions::Accept
                  STDOUT.puts "===> ACCEPT" if explain
                  node_stack << csn
                  break
                  
               when NilClass
                  STDOUT.puts "===> ERROR: unexpected token: #{next_token}"
                  exit
                                    
               else
                  nyi "support for #{action.class.name}"
            end

         end
         
         return node_stack[-1]
      end
      




    #---------------------------------------------------------------------------------------------------------------------
    # Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    private
    
    
      #
      # rewind()
      #  - rewinds the lexer to where it was when it produced the specified token
      
      def rewind( before_token )
      end
    
          
      #
      # la()
      #  - looks ahead one or more tokens
      
      def la( count = 1 )
         until @lookahead.length >= count
            if token = @lexer.next_token() then
               @lookahead << token
            else
               nyi "error handling for lexer error" if @lexer.input_remaining?
               break
            end
         end
         
         return @lookahead[count-1]
      end
      
      
      #
      # consume()
      #  - shifts the next token off the lookahead and returns it
      
      def consume()
         la(1)
         return @lookahead.shift
      end
      
      
      
      #
      # find_shift()
      #  - looks for a shift operation matching the specified Token 
      
      def find_shift( state, token )
         state.terminals.each do |terminal|
            if token.matches_terminal?(terminal) then
               return state.transitions[terminal]
            end
         end
         
         return nil
      end
      
      
      #
      # find_goto()
      #  - looks for a goto operation matching the specified Form
      
      def find_goto( state, form )
         state.reductions.each do |item|
            if item.form.object_id == form.object_id then
               return 
            end
         end
         
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
