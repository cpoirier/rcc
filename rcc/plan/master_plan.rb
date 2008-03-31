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
require "#{$RCCLIB}/scanner/artifacts/name.rb"
require "#{$RCCLIB}/plan/symbol.rb"
require "#{$RCCLIB}/plan/production.rb"
require "#{$RCCLIB}/plan/discarder.rb"
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
      
      Name = Scanner::Artifacts::Name
      
      
      #
      # ::build()
      #  - builds a MasterPlan from a Model::System
      
      def self.build( system_model, explain = true )
         debug_production_build = false
         
         #
         # Plan the AST and base Lexer for each Grammar.

         ast_plans         = {}
         master_lexer_plan = LexerPlan.new()
         lexer_plans       = {}

      
         #
         # Produces a global set of Productions, in declaration order.  Note that Grammar.rules contains
         # more than just Rules.  We care only about the Rules.
         
         productions   = []
         group_members = {}
         system_model.grammars.each do |grammar_model|
            grammar_name = grammar_model.name
            
            ast_plan = {}
            ast_plans[grammar_name] = ast_plan

            #
            # Move the lexer data into the master LexerPlan.
            
            grammar_model.strings.each do |symbol_name, string_descriptor|
               if string_descriptor.explicit? then
                  master_lexer_plan.add_open_pattern( symbol_name, string_descriptor.form )
               else
                  master_lexer_plan.add_closed_pattern( symbol_name, string_descriptor.form )
               end
            end
            
            lexer_plans[grammar_name] = master_lexer_plan.prioritize( grammar_model.strings.keys )


            #
            # Generate Discarders for each potential combination of ignored symbols.  We'll
            # link these to Symbols when constructing real Productions, and then 
            # State.enumerate_transitions() will apply those additional transitions.  We do it this 
            # way -- instead of just making extra Productions that allow ignored whitespace -- to
            # avoid unnecessary Production explosion.

            prefilter_names = {}
            ignore_symbols  = grammar_model.ignore_symbols

            default_prefilter = nil
            ignore_symbols.subsets(true).each do |set|
               next if set.empty?
               names = set.sort.collect{|e| e.name}
               
               production_name   = Name.new( "_ignored_" + names.join("_"), grammar_name )
               production_symbol = Symbol.new( production_name, :production )
               prefilter_names[names.join("|")] = production_name

               default_prefilter = production_symbol if default_prefilter.nil?
               
               set.each do |name|
                  base_symbol = Symbol.new( name, :token )
                  productions << Discarder.new( productions.length, production_name, [base_symbol], [], :left, 0, nil )
               end
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
                     
                     #
                     # At this point, we have to integrate handling for ignored symbols.  This is generally 
                     # done by associating the appropriate ignore rule name with the Symbol that will follow
                     # it.  State.enumerate_transitions() will then account for that additional lookahead 
                     # option.  We use the default_ignore_rule for most Symbols, UNLESS there is one or more
                     # declared GatewayMarkers in the sequence, in which case an alternative rule name will
                     # be chosen.  However, for trailing GatewayMarkers, we have to do something different.
                     # Such GatewayMarkers affect the Reduce/Discard actions, and so must be associated with
                     # the Production itself.  

                     slots              = []
                     symbols            = []
                     reduction_gateways = []
                     gateway_buffer     = []
                     
                     elements = sequence
                     sequence.each_element do |element|
                        if element.is_a?(Model::Markers::GatewayMarker) then
                           gateway_buffer << element.symbol_name
                        else
                           slots << element.slot_name
                           ast_class.define_slot( element.slot_name, false ) unless element.slot_name.nil? 
                           
                           prefilter = default_prefilter
                           unless gateway_buffer.empty?
                              prefilterable_names = gateway_buffer & ignore_symbols
                              unless prefilterable_names.empty?
                                 prefilter = prefilter_names[prefilterable_names.sort.join("|")]
                              end
                           end

                           case element
                              when Model::Markers::RuleReference
                                 symbols << Symbol.new( element.symbol_name, :production, prefilter )
                              when Model::Markers::StringReference
                                 symbols << Symbol.new( element.symbol_name, :token     , prefilter )
                              when Model::Markers::GroupReference
                                 symbols << Symbol.new( element.symbol_name, :group     , prefilter )
                              when Model::Markers::RecoveryCommit
                                 symbols[-1].recoverable = true unless symbols.empty?
                              else
                                 nyi( "support for [#{element.class.name}]", element )
                           end
                        end
                     end

                     postfilter = default_prefilter
                     unless gateway_buffer.empty?
                        postfilterable_names = gateway_buffer & ignore_symbols
                        unless postfilterable_names.empty?
                           postfilter = prefilter_names[postfilterable_names.sort.join("|")]
                        end
                     end
                     
                     warn_nyi( "support for trailing gateway markers" )
                     production = Production.new( productions.length, rule.name, symbols, slots, rule.associativity, rule.priority, ast_class, sequence.minimal?, postfilter )
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
            
            
            #
            # Map Group names to Rule name.
            
            grammar_model.groups.each do |group|
               members = []
               group.member_references.each do |element|
                  case element
                     when Model::Markers::RuleReference
                        members << Symbol.new( element.symbol_name, :production )
                     when Model::Markers::StringReference
                        members << Symbol.new( element.symbol_name, :token      )
                     else
                        nyi( "support for [#{element.class.name}]", element )
                  end
               end
               
               group_members[group.name] = members
            end
            
         end
         
         return MasterPlan.new( productions, group_members, ast_plans, lexer_plans, explain )
      end
      
      
      
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_accessor :produce_explanations
      attr_reader   :production_sets
      attr_reader   :group_members
      attr_reader   :lexer_plans
      
      def initialize( productions, group_members, ast_plans, lexer_plans, produce_explanations = true )
         @productions          = productions
         @group_members        = group_members
         @ast_plans            = ast_plans
         @lexer_plans          = lexer_plans                # grammar name => LexerPlan
         @produce_explanations = produce_explanations       # If true, we'll generate explanations
         
         #
         # Associate our Productions with this MasterPlan.
         
         @productions.each do |production|
            production.master_plan = self
         end
         
         #
         # Index the @productions by grammar_name and symbol_name, preserving order.
         
         @production_sets = Util::OrderedHash.new( ProductionSet )
         @productions.each do |production|
            @production_sets[production.name] << production
         end
         
         @group_members.each do |name, members|
            members.each do |member|
               if member.refers_to_production? then
                  @production_sets[member.name].productions.each do |production|
                     @production_sets[name] << production
                  end
               end
            end
         end
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
      
      def compile_parser_plan( name )
         case name
         when Model::Markers::RuleReference, Plan::Symbol
            name = name.name
         end

         assert( @production_sets.member?(name), "not a valid start rule name" )
         warn_nyi( "source trailing ignore support" )
         start_state = State.start_state( self, name.grammar, self.production_sets[name] )
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
               current_state.enumerate_transitions do |symbol_name, shifted_items|
                  
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
               
                  current_state.add_transition( symbol_name, transition_state )
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
         
         return ParserPlan.new( self, name.grammar, state_table, true )
      end
      
      
      

   end # MasterPlan
   


end  # module Plan
end  # module RCC
