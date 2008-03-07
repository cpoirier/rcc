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
require "#{$RCCLIB}/plan/production.rb"
require "#{$RCCLIB}/plan/ast_class.rb"
require "#{$RCCLIB}/plan/lexer_plan.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class MasterPlan
 #  - houses all the common elements of the Plan, for a single Grammar System

   class MasterPlan
      
      #
      # ::build()
      #  - builds a MasterPlan from a Model::System
      
      def self.build( system_model, start_rule_names )
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
                              options = []
                              element.group.member_references.each do |reference|
                                 case reference
                                    when Model::References::RuleReference
                                       options << Symbol.new( reference.symbol_name.namespace(grammar_model.name), reference.symbol_name, false )
                                    when Model::References::StringReference
                                       options << Symbol.new( reference.symbol_name.namespace(grammar_model.name), reference.symbol_name, true  )
                                    else
                                       nyi( "support for [#{element.class.name}]", element )
                                 end
                              end
                              
                              symbols << options
                           when Model::References::RecoveryCommit
                              symbols[-1].recoverable = true unless symbols.empty?
                           else
                              nyi( "support for [#{element.class.name}]", element )
                        end
                     end
                     
                     warn_nyi( "minimal phrasing marker" )
                     
                     production = Production.new( productions.length, grammar_model.name, rule.name, symbols, slots, rule.associativity, rule.priority, ast_class, false )
                     
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
      end
      
      
      
      def generate_plan( grammar_name, start_rule )
         
      end
      
      
      
      
      
      
   end # MasterPlan
   


end  # module Plan
end  # module RCC
