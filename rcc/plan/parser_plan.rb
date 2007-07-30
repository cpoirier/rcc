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
require "rcc/plan/ast_class.rb"
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
         # for each rule name.  Finally, we'll construct an ASTClass hierarchy.
         
         productions      = []
         production_sets  = {}
         ast_classes      = {}
         form_lookup      = {}    # form id_number => Production
         
         grammar.forms.each do |form|
            form_lookup[form.id_number] = []
            
            form.phrases.each do |phrase|
               symbols    = phrase.symbols.collect {|model| Plan::Symbol.new(model.name, model.terminal?, model.slot) }
               production = Production.new( productions.length + 1, form.rule.name, symbols, form.associativity, form.id_number, form )
               
               productions << production
               form_lookup[form.id_number] << production
               
               production_sets[production.name] = ProductionSet.new(production.name) unless production_sets.member?(production.name)
               production_sets[production.name] << production
               
               #
               # Build an AST plan for our Productions.
               
               ast_classes[form.rule.name] = ASTClass.new( form.rule.name ) unless ast_classes.member?(form.rule.name)
               base_class = ast_classes[form.rule.name]
               form_class = nil
               
               if form.label.nil? then
                  base_class.catch_all_class.merge_slots( production, false )
               else
                  bug( "duplicate name in AST" ) if ast_classes.member?(form.label)
                  form_class = ASTClass.new( form.label, base_class )
                  form_class.merge_slots( production )
                  ast_classes[form.label] = form_class
               end
                  
               production.ast_class = base_class.catch_all_class
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
                  transition_state = State.new( state_table.length, shifted_items, current_state )
                  transition_state.close( production_sets )
                  
                  state_table << transition_state
                  state_index[transition_state.signature] = transition_state
                  
                  work_queue << transition_state
               end
               
               current_state.add_transition( symbol_name, transition_state )
            end

            # current_state.display( STDOUT, "" )
         end
         
         
         #
         # Close the State Items.
         
         state_table.each do |state|
            state.close_items()
         end
         
         
         #
         # Return the new ParserPlan.
         
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
      
      def compile_actions( explain = false, k_limit = 1, use_backtracking = false )
         @state_table.each do |state|
            state.compile_actions( @production_sets, @precedence_table, k_limit, use_backtracking, explain )
         end
      end



    

   
   
   
   
   
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Grammar #{@name}"
      end
      
      def display( stream, indent = "", complete = true, show_context = :reduce_determinants )
         stream << indent << "States\n"
         @state_table.each do |state|
            state.display( stream, "   ", complete, show_context )
         end
      end
      
   



      
   end # Grammar
   


end  # module Model
end  # module Rethink




# This code is garbage (unfinished finished), but might come in useful again.  Stored here for now.
#
#
# first_and_follow_sets()
#  - returns a hash, mapping potential first terminals to all potential follow phrases for this rule
#  - don't call this before all Forms have been added
#  - NOTE: during analysis, any child calls my have no choice but to produce output that includes non-terminal
#    firsts; this should never be the case for the outer-most call
#
# def first_and_follow_sets( loop_detector = nil )
#    return @first_and_follow_sets unless @first_and_follow_sets.nil?
#    loop_detector = Util::RecursionLoopDetector.new() if loop_detector.nil?
#    
#    #
#    # Calculate the first and follows sets.  Any Phrase that begins with a Terminal is our friend.
#    # Any Phrase that begins with a NonTerminal will require a lot more work.
#    
#    first_and_follow_sets = {}
#    complete = loop_detector.monitor(self.object_id) do
# 
#       follow_by_terminal_firsts     = {}
#       follow_by_non_terminal_firsts = {}
#       
#       #
#       # Go through all the Phrases in our Forms and sort them.  Terminal-led Phrases go straight into our finished
#       # set.  NonTerminal-lead Phrases go in follow_by_non_terminal_firsts for further processing.
#       
#       @forms.each do |form|
#          form.phrases.each do |phrase|
#             next if phrase.length <= 0
#             
#             first  = phrase.symbol[0]
#             follow = phrase.slice(1..-1)
#             
#             set = first.terminal? ? follow_by_terminal_firsts : follow_by_non_terminal_firsts
#             set[first] = [] unless set.member?(first)
#             set[first] << follow
#          end
#       end
#       
#       #
#       # Next, we expand the NonTerminal firsts and produce the remainder of the first_and_follow_sets.  Any
#       # that start with our NonTerminal get deferred until the very end.
#       
#       follow_by_non_terminal_firsts.keys.each do |non_terminal|
#          next if non_terminal.name == @name
#          nyi( "error handling for missing non-terminals" ) unless @grammar.rules.member?(non_terminal)
#          
#          #
#          # Recurse to get the additional first and follow sets.  Any that return nil indicate that we tried to
#          # expand something further up the call chain, so we let it worry about those expansions.  If the first
#          # is a non-terminal, it is either ours, or something we can't expand due to a recursion loops.  In the
#          # latter case, we'll have to return it with the rest.
# 
#          child_first_and_follow_sets = @grammar.rules[rule_name].first_and_follow_sets( loop_detector )
#          unless child_first_and_follow_sets.nil? 
#             child_first_and_follow_sets.each do |first, follow_sets|
#                if first.terminal? then
#                   follow_by_terminal_firsts.array_set( first, PhraseJoin.new(follow_sets, follow_by_non_terminal_firsts[non_terminal]) )
#                elsif first.name == @name then
#                   follow_by_non_terminal_firsts[first] = [] unless follow_by_non_terminal_firsts.member?(first)
#                   follow_by_non_terminal_firsts.concat( follow_sets )
#                else
#                   follow_by_terminal_firsts[first] = [] unless follow_by_non_terminal_firsts.member?(first)
#                   bug( "why are we getting foreign non-terminals from our ") 
#                   
#                end
#                      
#                   
#             end
#          
#          # 
#          # We that done, every child_first_and_follow_set should begin with on of two things: a Terminal,
#          # or a NonTerminal that refers to us.
#          
#       end
#       
#    end
# 
#    #
#    # If we just looped, return nil.  Our earlier invokation will deal with it.  If the result we just
#    # calculated is complete, cache it for reuse.
#    
#    if complete.nil?
#       return nil
#    else
#       @first_and_follow_sets = first_and_follow_sets if complete
#       return first_and_follow_sets
#    end
# end
# 
# 
# 