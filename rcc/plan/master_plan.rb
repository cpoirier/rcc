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
require "#{$RCCLIB}/plan/character_range.rb"
require "#{$RCCLIB}/plan/character_map.rb"
require "#{$RCCLIB}/plan/production.rb"
require "#{$RCCLIB}/plan/production_set.rb"
require "#{$RCCLIB}/plan/ast_class.rb"
require "#{$RCCLIB}/plan/state.rb"
require "#{$RCCLIB}/plan/state_table.rb"
require "#{$RCCLIB}/plan/parser_plan.rb"
require "#{$RCCLIB}/plan/transformations/transform.rb"
require "#{$RCCLIB}/util/trail_marker.rb"


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
         discard_lists     = {}

      
         #
         # Produces a global set of Productions, in declaration order.  Note that Grammar.rules contains
         # more than just Rules.  We care only about the Rules.
                  
         productions   = []
         group_members = {}
         system_model.grammars.each do |grammar_model|
            grammar_name = grammar_model.name


            #
            # Move the lexer data into the master LexerPlan.
            
            grammar_model.patterns.each do |pattern|
               
               #
               # Each path through the master_form will become a single TokenProduction.

               pattern.master_form.paths.each do |branchpoint|
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

                     symbols  = []
                     elements = sequence
                     sequence.each_element do |element|
                        case element
                        when Model::Elements::CharacterRange
                           symbols << Plan::CharacterRange.from_model(element)
                        when Model::Markers::Reference
                           symbols << Symbol.new( element.symbol_name, :sequence )
                        else
                           nyi( "support for [#{element.class.name}] in Patterns", element )
                        end
                     end
                  
                     production = TokenProduction.new( productions.length, pattern.name, symbols, pattern.tokenizeable? )
                     productions << production

                     if debug_production_build then
                        $stderr.indent do
                           $stderr.puts "token production: "
                           $stderr.indent do
                              production.display( $stderr )
                           end
                           $stderr.end_line
                           $stderr.puts
                        end
                     end
                  end
               end
            end
            

            #
            # Process each Rule in the Grammar to produce SyntaxProductions and ASTClasses.
            
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
               ast_plans[rule.name.to_s] = ast_class
               
               
               #
               # Assemble the discard list for the rule.
               
               discards = []
               rule.discard_symbols.each do |symbol_name|
                  discards << Symbol.new( symbol_name, symbol_type_from_reference(symbol_name, system_model) )
               end
               
               
               #
               # Each path through the master_form will become a single Production. 
               
               $stderr.puts "#{rule.name}:" 
               $stderr.indent do
                  $stderr.puts "form:"
                  $stderr.indent do
                     rule.master_form.display($stderr)
                  end
                  $stderr.end_line
                  $stderr.puts 
               end
               
               
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
                     pending_commit     = nil
                     
                     elements = sequence
                     sequence.each_element do |element|
                        case element
                        when Model::Markers::GatewayMarker
                           gateway_buffer << Symbol.new( element.symbol_name, symbol_type_from_reference(element.symbol_name, system_model) )
                        when Model::Markers::LocalCommit
                           symbols[-1].commit_point = :local
                        else
                           slots << element.slot_name
                           ast_class.define_slot( element.slot_name, false ) unless element.slot_name.nil? 
                           
                           if element.is_a?(Model::Markers::Reference) then
                              symbols << Symbol.new( element.symbol_name, symbol_type_from_reference(element, system_model), gateway_buffer )
                           else
                              nyi( "support for type [#{element.class.name}]", element )
                           end

                           gateway_buffer.clear
                        end
                     end
                     
                     production = SyntaxProduction.new( productions.length, rule.name, symbols, slots, rule.associativity, rule.priority, ast_class, discards, sequence.minimal? )
                     productions << production

                     if !symbols.empty? and symbols[-1].commit_point.exists? then
                        production.commit_point = symbols[-1].commit_point
                        symbols[-1].commit_point = nil
                     end
                     
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
               
               
               #
               # Build plans for the transformations for this Rule and add them to the ASTClass.

               rule.transformations.each do |spec|
                  case spec.type.name
                  when "assignment_transform"
                     lhs_selector = build_transformation_selector( spec.destination, true )
                     rhs_selector = build_transformation_selector( spec.source            )
                     ast_class.transformations << Transformations::AssignmentTransform.new( lhs_selector, rhs_selector )

                  when "append_transform"
                     lhs_selector = build_transformation_selector( spec.destination, true )
                     rhs_selector = build_transformation_selector( spec.source            )
                     ast_class.transformations << Transformations::AppendTransform.new( lhs_selector, rhs_selector )
                  
                  when "unset_transform"
                     selector = build_transformation_selector( spec.destination, true )
                     ast_class.transformations << Transformations::UnsetTransform.new( selector )
                  end
               end
               
               
               #
               # Optionally display the build results.
               
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
                  members << Symbol.new( element.symbol_name, symbol_type_from_reference(element, system_model) )
               end
               
               group_members[group.name] = members
            end
            
         end
         
         return MasterPlan.new( productions, group_members, ast_plans, discard_lists, explain )
      end
      
      
      
      def self.symbol_type_from_reference( reference, system_model, fail_if_nil = true )
         symbol_type = nil
         
         object = nil
         if reference.is_a?(Scanner::Artifacts::Name) then
            object = system_model.resolve(reference)
         else
            object = reference.resolve(system_model)
         end
         
         case object
         when Model::Elements::Rule 
            symbol_type = :production
         when Model::Elements::Subpattern
            symbol_type = :sequence
         when Model::Elements::Pattern
            symbol_type = :token
         when Model::Elements::Group
            symbol_type = :group
         when NilClass
            bug( "error handling for unresolvable reference" ) if fail_if_nil
         else
            nyi( "support for type [#{object.class.name}]" )
         end
         
         return symbol_type
      end
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def produce_explanations?() ; return @produce_explanations ; end
      
      attr_writer :produce_explanations
      attr_reader :production_sets
      attr_reader :group_members
      attr_reader :ast_plans
      attr_reader :discard_lists
      
      def initialize( productions, group_members, ast_plans, discard_lists, produce_explanations = true )
         @productions            = productions
         @group_members          = group_members
         @ast_plans              = ast_plans
         @discard_lists          = discard_lists              # grammar name => [ Symbol ]
         @produce_explanations   = produce_explanations       # If true, we'll generate explanations
         @syntactic_determinants = {}                         # name => [ token names ]
         @lexical_determinants   = {}                         # name => CharacterRange
         
         
         #
         # Associate our Productions with this MasterPlan.
         
         @productions.each do |production|
            production.master_plan = self
         end
         
         #
         # Index the @productions by grammar_name and symbol_name, preserving order.
         
         @production_sets           = Util::OrderedHash.new( Array )
         @syntactic_production_sets = Util::OrderedHash.new( Array )
         @lexical_production_sets   = Util::OrderedHash.new( Array )
         
         @productions.each do |production|
            @production_sets[production.name] << production
            if production.syntactic? then
               @syntactic_production_sets[production.name] << production 
            else
               @lexical_production_sets[production.name] << production
            end
         end
         
         @group_members.each do |name, members|
            members.each do |member|
               if member.refers_to_production? then
                  @production_sets[member.name].each do |production|
                     @production_sets[name] << production
                  end
               end
            end
         end
      end
      
      
      #
      # register_transfer_production()

      def register_transfer_production( production )
         number = @productions.length
         production.instance_eval do
            @number = number
         end
         
         @productions << production
         return production
      end


      #
      # symbols_for()
      #  - returns an array of symbols, one for each name in a group
      #  - returns an array of the input symbol if not a group
      
      def symbols_for( symbol )
         return @group_members.member?(symbol.name) ? @group_members[symbol.name] : [symbol]
      end
      
      
      #
      # syntactic_determinants_for()
      #  - given a syntactic production name, returns a list of token symbols that can start it
      
      def syntactic_determinants_for( symbols, into = nil, trail_marker = nil )
         if symbols.is_an?(Array) then
            trail_marker = Util::TrailMarker.new() if trail_marker.nil?
            determinants = into.nil? ? {} : into
            
            symbols.each do |symbol|
               syntactic_determinants_for( symbol, determinants, trail_marker )
            end
            
            return into.nil? ? determinants.keys : into
            
            
         else
            symbol = symbols
            name   = symbol.name
            
            if @syntactic_determinants.member?(name) then
               if into.nil? then
                  return @syntactic_determinants[name]
               else
                  into.update(@syntactic_determinants[name].to_hash())
                  return into
               end
            end

            trail_marker = Util::TrailMarker.new() if trail_marker.nil?
            determinants = {}
            complete     = false
         
            if @group_members.member?(name) then
               group = @group_members[name]
               complete = trail_marker.enter(group.object_id) do
                  group.each do |member|
                     if member.refers_to_token? then
                        determinants[member] = true
                     else
                        syntactic_determinants_for(member, determinants, trail_marker) if trail_marker.mark(member.name)
                     end
                  end
               end
            elsif @syntactic_production_sets.member?(name) then
               production_set = @syntactic_production_sets[name]
               complete = trail_marker.enter(production_set.object_id) do
                  production_set.each do |production|
                     leader = production.symbols[0]
                     if leader.refers_to_token? then
                        determinants[leader] = true
                     else
                        syntactic_determinants_for(leader, determinants, trail_marker) if trail_marker.mark(leader.name)
                     end
                  end
               end
            elsif name.character_range?() then
               determinants[name.name] = true
            else
               determinants[Plan::Symbol.new(name, :token)] = true
            end
         
            into.update( determinants ) unless into.nil?


            #
            # Cache the answer and return.
         
            @syntactic_determinants[name] = determinants.keys if complete
            return into.nil? ? determinants.keys : into
         end
      end


      #
      # lexical_determinants_for()
      #  - given a lexical production name, returns a CharacterRange of codes that can start it

      def lexical_determinants_for( symbols, visited = {} )
         if symbols.is_an?(Array) then
            determinants = CharacterRange.new()
            symbols.each do |symbol|
               determinants.add( lexical_determinants_for(symbol) )
            end
            return determinants
            
         else
            symbol = symbols
            name   = symbol.name
            
            #
            # Unlike SyntaxProduction, TokenProductions are strictly acyclic.  So we'll recurse instead.
         
            determinants = CharacterRange.new()
            symbols      = @lexical_production_sets.member?(name) ? [symbol] : syntactic_determinants_for( symbol )
         
            symbols.each do |symbol|
               if symbol.refers_to_character? then
                  determinants.add(symbol)
               else
                  token_name = symbol.name
               
                  next if visited.member?(token_name)
                  visited[token_name] = true
               
                  if @lexical_determinants.member?(token_name) then
                     determinants += @lexical_determinants[token_name]
                  elsif @lexical_production_sets.member?(token_name) then
                     production_set = @lexical_production_sets[token_name]
                     unless production_set.empty?
                        assert( production_set[0].lexical?, "expected lexical production for #{token_name}!" )

                        set_determinants = CharacterRange.new()
                        production_set.each do |production|
                           leader = production.symbols[0]
                           if leader.refers_to_character? then
                              set_determinants += leader
                           else
                              set_determinants += lexical_determinants_for( leader, visited ) unless visited.member?(leader.name)
                           end
                        end
               
                        @lexical_determinants[token_name] = set_determinants
                        determinants += set_determinants
                     end
                  elsif token_name.eof? then
                     determinants.add( -1..-1 ) 
                  else
                     nyi( "lexical determinant support for #{token_name}", symbol )
                  end
               end
            end
            
            return determinants
         end
      end







    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # compile_parser_plan()
      #  - generates a ParserPlan for a specific start rule
      
      def compile_parser_plan( name )
         case name
         when Model::Markers::Reference, Plan::Symbol
            name = name.name
         end

         assert( @production_sets.member?(name), "not a valid start rule name" )
         state_table = StateTable.build( self, name )

         return ParserPlan.new( self, name.grammar, state_table )
      end
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # Build support
    #---------------------------------------------------------------------------------------------------------------------

    private
    
    
      #
      # build_transformation_selector()
      #  - for LHS selectors, set potential_target on the outermost call
      
      def self.build_transformation_selector( spec, potential_target = false )
         selector = nil
         
         case spec.type.name
         when "npath_predicate_exp"
            body      = build_transformation_selector( spec.npath, potential_target )
            predicate = build_transformation_predicate( spec.npred )
            
            #
            # The only thing valid after an LHS target element is a predicate, which may eliminate the 
            # target.  For such handling, we assign the predicate directly to the target element, so it
            # can evaluate it before doing the assignment.
            
            if potential_target and targets = body.targets then
               targets.each{ |target| target.target_predicate = predicate }
               selector = body
            else
               selector = Transformations::SelectorSequence.new( body, predicate )
            end
         when "npath_path_exp"
            selector = Transformations::SelectorSequence.new( build_transformation_selector(spec.tree), build_transformation_selector(spec.leaf, potential_target) )
         when "npath_slot_exp"
            selector = Transformations::SelectorSequence.new( Transformations::SlotSelector.new(spec.slot_name.text, potential_target) )
         when "npath_tclose_exp"
            selector = Transformations::SelectorSequence.new( Transformations::TransitiveClosure.new(build_transformation_selector(spec.npath, potential_target)) )
         when "npath_branch_exp"            
            selector = Transformations::SelectorBranch.new( build_transformation_selector(spec.tree, potential_target), build_transformation_selector(spec.leaf, potential_target) )
         when "npath_self_exp"
            selector = Transformations::SelectorSequence.new( Transformations::SelfSelector.new(potential_target) )
         when "npath_reverse_exp"
            selector = Transformations::SelectorSequence.new( Transformations::ReverseSelector.new(build_transformation_selector(spec.npath, potential_target)) )
         else
            nyi( "support for [#{spec.type.name}]", spec )
         end
         
         return selector
      end
      

      #
      # build_transformation_predicate()
      
      def self.build_transformation_predicate( spec )
         predicate = nil
         
         case spec.type.name
         when "npred_type_exp"
            predicate = Transformations::PredicateAnd.new( Transformations::TypePredicate.new(spec._type_name) )
         when "npred_negation_exp"
            case spec.npred.type.name
            when "npred_type_exp"
               predicate = Transformations::PredicateAnd.new( Transformations::NotTypePredicate.new(spec.npred._type_name) )
            else
               predicate = Transformations::PredicateAnd.new( Transformations::InvertedPredicate.new(build_transformation_predicate(spec.npred)) )
            end         
         when "npred_or_exp"
            predicate = Transformations::PredicateOr.new( build_transformation_predicate(spec.tree), build_transformation_predicate(spec.leaf) )
         when "npred_and_exp"
            predicate = Transformations::PredicateAnd.new( build_transformation_predicate(spec.tree), build_transformation_predicate(spec.leaf) )
         else
            predicate = Transformations::ExistsPredicate.new( build_transformation_selector(spec) )
         end   
                     
         return predicate
      end
      
      

   end # MasterPlan
   


end  # module Plan
end  # module RCC
