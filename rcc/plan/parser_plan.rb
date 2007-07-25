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
      
      def self.build( grammar, lexer_plan )
         
         #
         # Build our Productions from the Forms in the Grammar model.  We'll also build a hash of ProductionSets, one
         # for each rule name.
         
         productions     = []
         production_sets = {}
         
         grammar.forms.each do |form|
            form.phrases.each do |phrase|
               production = Production.new( productions.length + 1, form.rule.name, phrase, form.associativity, form.precedence, form.id_number, form )
               
               productions << production
               
               production_sets[production.name] = ProductionSet.new(production.name) unless production_sets.member?(production.name)
               production_sets[production.name] << production
            end
         end
         
         #
         # Next, get the Grammar's start rule and build it a State.  This will become the base of the complete state table.
         
         start_productions = production_sets[grammar.start_rule_name.intern]
         nyi "error handling for unknown start rule" if start_productions.nil?
         
         start_state = State.new( 1 )
         start_state.add_productions( start_productions, nil, production_sets )
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
         
         return new( state_table, productions, production_sets, lexer_plan )
      end
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :model          # The Model from which this Plan was build (if available)
      attr_reader :lexer_plan     # A LexerState that describes how to lex the Grammar

      def initialize( state_table, productions = nil, production_sets = nil, lexer_plan = nil )
         @state_table     = state_table
         @lexer_plan      = lexer_plan
         @productions     = productions
         @production_sets = production_sets
      end
      
      
      
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Parser construction
    #---------------------------------------------------------------------------------------------------------------------


      #
      # build_parser()
      #  - compiles the Grammar Rules to a State table
      
      def build_parser()
         
         #
         # Build first-Symbol and first-Terminal lists for every NonTerminal in the Grammar.  
         
         # @leading_symbols = {}
         # @productions_by_rule_name.each do |rule_name, productions|
         #    @leader_symbols[rule_name] = productions.collect{|production| production.symbols[0].name }.uniq
         # end
         # 
         # @leading_terminals = {}
         # 
         
         
         
         # 
         # 
         # We'll need these when
         # # constructing state tables.
         # 
         # @firsts_by_rule_name
         # work_queue = []
         # @productions_by_rule_name.each do |rule_name, productions|
         #    unless @first_by_rule_name.member?(rule_name)
         #       work_queue.concat( productions )
         #       until work_queue.empty?
         #          production = work_queue.shift
         #          
         #          
         #       end
         #    end
         # end
         # 
         # 
         # 
         # 
         # #
         # # Next, find the start rule of the grammar.
         # 
         # start_rule_name = @configuration["StartRule"]
         # nyi "error handling for missing start rule" if start_rule_name.nil?
         # 
         # start_productions = @productions_by_rule_name[start_rule_name]
         # nyi "error handling for unknown start rule" if start_productions.nil?
         # 
         # 
         # #
         # # Build the start State from the start Rule.
         # 
         # start_state = allocate_state()
         # start_state.add( start_productions )
         # 
         # 
         # #
         # # From the start state, build new states, one for each follow symbol.  Repeat for each new state
         # # until all are complete.
         # 
         # unfinished_states = [start_state]
         # until unfinished_states.empty?
         #    current_state = unfinished_states.shift
         #    
         #    #
         #    # Register the state as being created by it's start items (that's all that are 
         #    # in there, right now).
         #    
         #    current_state.start_items.each do |item|
         #       @states_by_start_productions[item.production.object_id] = [] unless @states_by_start_productions.member?(item.production.object_id)
         #       @states_by_start_productions[item.production.object_id] << current_state
         #    end
         #    
         #    #
         #    # Complete the state and construct any target states it will need.
         #    
         #    current_state.complete()
         #    current_state.enumerate_transitions do |symbol, items|               
         #       to_state = find_state( items )
         #       
         #       if to_state.nil? then
         #          to_state = current_state.add_transition( symbol, allocate_state() )
         # 
         #          items.each do |item|
         #             to_state.add(item)
         #          end
         #       
         #          unfinished_states << to_state
         #       else
         #          current_state.add_transition( symbol, to_state )
         #       end
         #    end
         #    
         #    #current_state.display( STDOUT, "" )
         # end
         # 
      end
      
      
      #
      # find_state()
      #  - looks for and returns any State that matches the supplied start Items
      
      def find_state( items )
         
         #
         # Go through @states_by_start_production and find any State started by any of the items.

         potential_states = nil
         items.collect{|item| item.production.object_id}.collect{|id| @states_by_start_productions[id]}.each do |set|
            if set.nil? then
               
               # If we are here, it indicates a rule is referenced but does not exist.  We'll let it pass, here,
               # and will report it in State.add_item() instead.
               
            else
               if potential_states.nil? then
                  potential_states = set
               else
                  potential_states &= set
               end
            end
         end
         
         #
         # Of those, we'll now search for a State that has ALL the requested Items.  There really
         # should only be one, so we'll return as soon as we find one.
         
         unless potential_states.nil?
            potential_states.each do |state|
               return state if state.matches?(items)
            end
         end
         
         return nil
      end
    
    
      #
      # find_productions()
      #  - returns a list of Productions that produce the specified rule name
      
      def find_productions( rule_name )
         return @productions_by_rule_name[rule_name]
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
