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

      def initialize( grammar, lexer )
         @grammar   = grammar
         @lexer     = lexer
         @lookahead = []
      end
      
      
      #
      # parse()
      #  - applies the Grammar to the inputs and builds a generic AST
      
      def parse( explain = false, start_state = nil )
         
         state_stack = [ start_state.nil? ? @grammar.state_table[0] : start_state ]
         node_stack  = []
         
         while true
            
            state = state_stack[-1]
            
            #
            # Deterimine our options for shift and reduce.
            
            next_token        = la()
            shift_to_state    = next_token.nil? ? nil : state.transitions[next_token.type]
            reduce_production = state.chosen_reduction.nil? ? nil : state.chosen_reduction.production

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
            end

            
            #
            # If we can't shift and can't reduce, it's time for some error recovery, methinks.
            
            if shift_to_state.nil? and reduce_production.nil? then
               STDOUT.puts "===> ERROR CORRECT" if explain
               nyi "error correction"
               
            
            #
            # OTOH, if can can both shift and reduce, we have a conflict.  Time to engage backtracking
            # support and try all the options, be decreasing precedence.
               
            elsif !shift_to_state.nil? and !reduce_production.nil? then
               if explain
                  STDOUT.puts "===> SHIFT/REDUCE CONFLICT"
                  STDOUT.puts "===> SHIFT #{next_token.description} AND GOTO #{shift_to_state.number}"
               end
               
               node_stack  << consume()
               state_stack << shift_to_state
             
               
            #
            # There's no reduce, and we can shift.  Seems like a good plan.

            elsif !shift_to_state.nil? then
               STDOUT.puts "===> SHIFT #{next_token.description} AND GOTO #{shift_to_state.number}" if explain

               node_stack  << consume()
               state_stack << shift_to_state

               
            #
            # There's no shift, and we can reduce.  Let's do it.

            else
               
               if explain
                  STDOUT.puts "===> REDUCE/REDUCE conflict" if state.reductions.length > 1
                  STDOUT.puts "===> REDUCE WITH #{reduce_production}"
               end
               
               #
               # First, collect enough nodes off the top of the stack to fill the CST.  Note also
               # that we must discard any states that were pending for those nodes.
               
               nodes = []
               reduce_production.symbols.length.times do 
                  nodes.unshift node_stack.pop
                  state_stack.pop
               end
               csn = CSN.new( reduce_production.output, nodes )
               
               #
               # Get the goto state from the now-top-of-stack State.  If there is no goto state,
               # we have reached the end of the line.  BUG: is that right?
               
               state      = state_stack[-1]
               goto_state = state.transitions[reduce_production.output]
               if goto_state.nil? then
                  if state_stack.length == 1 then
                     STDOUT.puts "===> ACCEPT" if explain
                     node_stack << csn
                     break
                  else
                     bug "why is there no goto state?"
                  end
               else
                  STDOUT.puts "===> PUSH AND GOTO #{goto_state.number}" if explain

                  node_stack  << csn
                  state_stack << goto_state
               end
            end
         end
         
         return node_stack[-1]
      end
      




    #---------------------------------------------------------------------------------------------------------------------
    # Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    private
    
          
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
