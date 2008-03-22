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
require "#{$RCCLIB}/plan/symbol.rb"
require "#{$RCCLIB}/plan/symbol_group.rb"
require "#{$RCCLIB}/plan/production.rb"
require "#{$RCCLIB}/plan/production_set.rb"
require "#{$RCCLIB}/plan/ast_class.rb"
require "#{$RCCLIB}/plan/lexer_plan.rb"
require "#{$RCCLIB}/plan/state.rb"
require "#{$RCCLIB}/plan/parser_plan.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class MasterPlan
 #  - houses all the common elements of the Plan, for a single Grammar System

   class MasterPlan
      
      #
      # ::build()
      #  - builds a MasterPlan from a Model::System
      
      def self.build( system_model )
         debug_production_build = false
         
         #
         # Plan the AST and base Lexer for each Grammar.

         ast_plans         = {}
         master_lexer_plan = LexerPlan.new()

      
         #
         # Produces a global set of Productions, in declaration order.  Note that Grammar.rules contains
         # more than just Rules.  We care only about the Rules.
         
         productions = []
         system_model.grammars.each do |grammar_model|
            ast_plan = {}
            ast_plans[grammar_model.name] = ast_plan
 
            #
            # Move the lexer data into the master LexerPlan.
            
            grammar_model.strings.each do |symbol_name, string_pattern|
               master_lexer_plan.add_pattern( grammar_model.name, symbol_name, string_pattern.pattern, string_pattern.explicit? )
            end
            

            #
            # Process each Rule in the Gramar to produce Productions and ASTClasses.
            
            grammar_model.rules.each do |rule|
               next unless rule.is_a?(Model::Elements::Rule)
            
               if debug_production_build then
                  $stderr.puts "#{rule.name}:" 
                  $stderr.indent do
                     $stderr.puts "form:"
                     $stderr.indent do
                        rule.master_form.display($stderr)
                     end
                     $stderr.end_line
                     $stderr.puts 
                  end
               end


               #
               # Create and register the ASTClass for this rule.
               
               ast_class = ASTClass.new( rule.name.to_s )
               ast_plan[rule.name.to_s] = ast_class
               
               
               #
               # Each path through the master_form will become a single Production. 
               
               rule.master_form.paths.each do |branchpoint|
                  branchpoint.each_element do |sequence|
                     if debug_production_build then
                        $stderr.indent do 
                           $stderr.puts "path:"
                           $stderr.indent() do
                              sequence.display($stderr)
                           end
                           $stderr.end_line
                           $stderr.puts 
                        end
                     end
                     
                     slots   = []
                     symbols = []
                     sequence.each_element do |element|
                        slots << element.slot_name
                        ast_class.define_slot( element.slot_name, false ) unless element.slot_name.nil? 
                                                
                        case element
                           when Model::References::RuleReference
                              symbols << Symbol.new( element.symbol_name.namespace(grammar_model.name), element.symbol_name, false )
                           when Model::References::StringReference
                              symbols << Symbol.new( element.symbol_name.namespace(grammar_model.name), element.symbol_name, true  )
                           when Model::References::GroupReference
                              group = SymbolGroup.new()
                              element.group.member_references.each do |reference|
                                 case reference
                                    when Model::References::RuleReference
                                       group << Symbol.new( reference.symbol_name.namespace(grammar_model.name), reference.symbol_name, false )
                                    when Model::References::StringReference
                                       group << Symbol.new( reference.symbol_name.namespace(grammar_model.name), reference.symbol_name, true  )
                                    else
                                       nyi( "support for [#{element.class.name}]", element )
                                 end
                              end
                              
                              symbols << group
                           when Model::References::RecoveryCommit
                              symbols[-1].recoverable = true unless symbols.empty?
                           else
                              nyi( "support for [#{element.class.name}]", element )
                        end
                     end
                     
                     production = Production.new( productions.length, grammar_model.name, rule.name, symbols, slots, rule.associativity, rule.priority, ast_class, sequence.minimal? )
                     productions << production
                     
                     if debug_production_build then
                        $stderr.indent do
                           $stderr.puts "production: "
                           $stderr.indent do
                              production.display( $stderr )
                           end
                           $stderr.end_line
                           $stderr.puts
                        end
                     end
                  end
               end
               
               if debug_production_build then
                  $stderr.indent do
                     $stderr.indent do
                        ast_class.display( $stderr )
                     end
                     $stderr.end_line
                     $stderr.puts
                  end
               end
            end
         end
         
         warn_nyi( "precedence table support" )
         return MasterPlan.new( productions, ast_plans, master_lexer_plan )
      end
      
      
      
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( productions, ast_plans, master_lexer_plan )
         @productions       = productions
         @ast_plans         = ast_plans
         @master_lexer_plan = master_lexer_plan
         @lexer_plans       = {}                     # grammar_name => prioritized LexerPlan

         
         #
         # Associate our Productions with this MasterPlan.
         
         @productions.each do |production|
            production.master_plan = self
         end
         
         #
         # Index the @productions by grammar_name and symbol_name, preserving order.
         
         @production_sets = Util::OrderedHash.new( lambda{Util::OrderedHash.new(ProductionSet)} )
         @productions.each do |production|
            @production_sets[production.grammar_name][production.rule_name] << production
         end
         
      end
      
      
      #
      # get_production_set()
      #  - returns the named ProductionSet, or nil
      #  - you can pass (grammar_name, symbol_name) or a Symbol
      
      def get_production_set( *args )
         grammar_name, symbol_name = *determine_name( *args )

         if @production_sets.member?(grammar_name) then
            if @production_sets[grammar_name].member?(symbol_name) then
               return @production_sets[grammar_name][symbol_name]
            end
         end
         
         return nil
      end
      
      
      #
      # has_production_set?()
      
      def has_production_set?( *args )
         grammar_name, symbol_name = *determine_name( *args )
         return @production_sets.member?(grammar_name) && @production_sets[grammar_name].member?(symbol_name)
      end
      
      
      #
      # get_lexer_plan()
      #  - returns a LexerPlan prioritized for the named grammar
      
      def get_lexer_plan( grammar_name )
         assert( @production_sets.member?(grammar_name), "cannot get prioritized LexerPlan for non-existent grammar [#{grammar_name}]" )
         @lexer_plans[grammar_name] = @master_lexer_plan.prioritize(grammar_name) unless @lexer_plans.member?(grammar_name)
         return @lexer_plans[grammar_name]
      end
      
      
      #
      # get_ast_plan()
      #  - returns the ASTPlan for the named grammar
      
      def get_ast_plan( grammar_name )
         assert( @ast_plans.member?(grammar_name), "cannot get AST plan for non-existent grammar [#{grammar_name}]" )
         return @ast_plans[grammar_name]
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # compile_parser_plan()
      #  - generates a ParserPlan for a specific start rule
      #  - you must pass the grammar_name and symbol_name (or a Symbol or RuleReference that can provide it)
      
      def compile_parser_plan( *args )
         grammar_name, start_rule_name = *determine_name( *args )
         
         assert( @production_sets.member?(grammar_name) && @production_sets[grammar_name].member?(start_rule_name), "not a valid start rule name" )
         start_state = State.start_state( self, get_production_set(grammar_name, start_rule_name) )
         start_state.close()
         
         
         #
         # From the start state, build new states, one for each follow symbol.  Repeat for each new state until all are complete.  
         # We take some pains, here, to avoid creating new states that have the same signature as old states.  We are trying to
         # be LALR(k), after all.
         
         state_table = [ start_state ]
         state_index = { start_state.signature => start_state }
         
         duration = Time.measure do
            work_queue = [start_state]
            until work_queue.empty?
               current_state = work_queue.shift
               current_state.enumerate_transitions do |symbol_signature, shifted_items|
                  
                  #
                  # If a matching state is already is in the index, all we need to do is merge in the lookahead 
                  # from the new contexts.  
               
                  if transition_state = state_index[State.signature(shifted_items)] then
                     transition_state.add_contexts( shifted_items, current_state )    
                  
                  #
                  # Otherwise, we need to create a new State from the shifted_items.
               
                  else
                     transition_state = State.new( self, state_table.length, shifted_items, current_state )
                     transition_state.close()
                  
                     state_table << transition_state
                     state_index[transition_state.signature] = transition_state
                  
                     work_queue << transition_state
                  end
               
                  current_state.add_transition( symbol_signature, transition_state )
               end
         
               # current_state.display( STDOUT, "" )
            end
         end
         
         STDERR.puts "State generation duration: #{duration}s" if $stderr['show_statistics']
         
         
         #
         # Close the State Items.
         
         duration = Time.measure do
            state_table.each do |state|
               state.close_items()
            end
         end
         
         STDERR.puts "Follow context propagation duration: #{duration}s" if $stderr['show_statistics']
         
         
         #
         # Return the new ParserPlan.
         
         return ParserPlan.new( self, grammar_name, state_table, true )
      end
      
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Support
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      def determine_name( *args )
         grammar_name = nil
         symbol_name  = nil
         
         if args.length == 2 then
            grammar_name, symbol_name = *args
         else
            case args[0]
               when Model::References::RuleReference
                  grammar_name = args[0].rule_name.namespace
                  symbol_name  = args[0].rule_name.to_s
               when Symbol
                  grammar_name = args[0].grammar_name
                  symbol_name  = args[0].symbol_name                  
               else
                  bug( "huh?" )
            end
         end
         
         return [grammar_name, symbol_name]
      end
      
      
   end # MasterPlan
   


end  # module Plan
end  # module RCC
