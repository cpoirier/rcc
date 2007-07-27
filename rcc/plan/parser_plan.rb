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
require "rcc/util/ordered_hash.rb"
require "rcc/model/rule.rb"
require "rcc/plan/production.rb"
require "rcc/plan/production_set.rb"
require "rcc/plan/state.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class ParserPlan
 #  - a plan for a backtracking LALR(1) parser that implements a Model::Grammar
 #  - whereas the Model Grammar deals in Rules and Forms, we deal in Productions; we both deal in Symbols

   class ParserPlan
      
      
      #
      # build()
      #  - builds a ParserPlan from a Model::Grammar and an optional LexerPlan
      
      def self.build( grammar, lexer_plan, start_rule_name = nil )
         
         #
         # Build our Productions from the Forms in the Grammar model.  We'll also build a hash of ProductionSets, one
         # for each rule name.
         
         productions      = []
         production_sets  = {}
         form_lookup      = {}    # form id_number => Production
         
         grammar.forms.each do |form|
            form_lookup[form.id_number] = []
            
            form.phrases.each do |phrase|
               production = Production.new( productions.length + 1, form.rule.name, phrase, form.associativity, form.id_number, form )
               
               productions << production
               form_lookup[form.id_number] << production
               
               production_sets[production.name] = ProductionSet.new(production.name) unless production_sets.member?(production.name)
               production_sets[production.name] << production
            end
         end

         
         #
         # Build a precedence table from the Grammar model.  Production number => tier number.  The Model table can
         # contain both Rules and Forms.  For Rules, we apply the precedence to all Forms, unless a higher precedence
         # has already been set for a particular Form. 
         
         precedence_table = {}
         grammar.precedence_table.rows.each_index do |index|
            row = grammar.precedence_table.rows[index]
            row.each do |form_or_rule|
               if form_or_rule.is_a?(Model::Rule) then
                  form_or_rule.forms.each do |form|
                     form_lookup[form.id_number].each do |production|
                        precedence_table[production.number] = index unless precedence_table.member?(production.number)
                     end
                  end
               else 
                  form_lookup[form_or_rule.id_number].each do |production|
                     precedence_table[production.number] = index
                  end
               end
            end
         end
         
         
         #
         # Next, get the Grammar's start rule and build it a State.  This will become the base of the complete state table.
         
         start_rule_name = grammar.start_rule_name if start_rule_name.nil?
         nyi "error handling for unknown start rule #{start_rule_name}" if start_rule_name.nil? or !grammar.rules.member?(start_rule_name)

         start_state = State.start_state( start_rule_name, production_sets )
         start_state.close( production_sets )

         
         #
         # From the start state, build new states, one for each follow symbol.  Repeat for each new state until all are complete.  
         # We take some pains, here, to avoid creating new states that have the same signature as old states.  We are trying to
         # be LALR(k), after all.

         state_table = [ start_state ]
         state_index = { start_state.signature => start_state }
         
         work_queue = [start_state]
         until work_queue.empty?
            current_state = work_queue.shift
            
            current_state.enumerate_transitions do |symbol_name, shifted_items|

               #
               # If a matching state is already is in the index, all we need to do is merge in the lookahead from 
               # the new contexts.  
               
               if transition_state = state_index[State.signature(shifted_items)] then
                  transition_state.add_contexts( shifted_items, current_state )    
                  
               #
               # Otherwise, we need to create a new State from the shifted_items.
               
               else
                  transition_state = State.new( state_table.length + 1, shifted_items, current_state )
                  transition_state.close( production_sets )
                  
                  state_table << transition_state
                  state_index[transition_state.signature] = transition_state
                  
                  work_queue << transition_state
               end
               
               current_state.add_transition( symbol_name, transition_state )
            end

            # current_state.display( STDOUT, "" )
         end
         
         return new( state_table, productions, production_sets, precedence_table, lexer_plan )
      end
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :model          # The Model from which this Plan was build (if available)
      attr_reader :lexer_plan     # A LexerState that describes how to lex the Grammar
      attr_reader :state_table    # Our States, in convenient table form

      def initialize( state_table, productions = nil, production_sets = nil, precedence_table = nil, lexer_plan = nil )
         @state_table      = state_table
         @lexer_plan       = lexer_plan
         @productions      = productions
         @production_sets  = production_sets    
         @precedence_table = precedence_table    # Production number => tier (tier 0 is highest precedence)
      end
      
      
      
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Parser construction
    #---------------------------------------------------------------------------------------------------------------------


      #
      # compile_actions()
      #  - runs through all our State tables and builds Actions that can drive a compiler
      #  - optionally constructs explanations for conflict resolutions
      
      def compile_actions( explain = false, k_limit = 1 )
         @state_table.each do |state|
            state.compile_actions( @production_sets, @precedence_table, k_limit, explain )
         end
      end



    

   
   
   
   
   
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Grammar #{@name}"
      end
      
      def display( stream, indent = "" )
         stream << indent << "States\n"
         @state_table.each do |state|
            state.display( stream, "   " )
         end
      end
      
   



      
   end # Grammar
   


end  # module Model
end  # module Rethink
