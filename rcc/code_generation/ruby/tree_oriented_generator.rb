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
require "rcc/code_generation/formatter.rb"

module RCC
module CodeGeneration
module Ruby

 
 #============================================================================================================================
 # class TreeOrientedGenerator
 #  - code generator for Ruby output
 #  - generates an object-tree-based parser, with all decisions and actions held in an a walkable object-tree

   class TreeOrientedGenerator < Generator
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( configuration )
         @configuration = configuration
      end
   
   
      #
      # generate()
      #  - generates a lexer, parser, and AST set for the supplied parser_plan, into the specified directory
      #  - generates to STDOUT if output_directory is nil
      
      def generate( parser_plan, output_directory = nil )
         # generate_lexer( parser_plan, output_directory )
         generate_parser( parser_plan, output_directory )
      end
   
   
   
   
   

    #---------------------------------------------------------------------------------------------------------------------
    # Parser Generation
    #---------------------------------------------------------------------------------------------------------------------
    
    private
    
      #
      # generate_parser()
      #  - generates a Parser and all the related machinery
      
      def generate_parser( parser_plan, output_directory )
         
         #
         # We only build an AST-producing Parser if requested.
         
         asn_lookup = nil
         if @configuration.member?(:build_ast) and @configuration[:build_ast] then
            asn_lookup = {}
            parser_plan.productions.each do |production|
               asn_lookup[production.label] = make_class_name(production.label)
            end
         end
         
         template_name = asn_lookup.nil? ? "tree_based_parser_for_node_processing.rb" : "tree_based_parser_for_ast_processing.rb"
         
         #
         # Process the template.
            
         fill_template(template_name, STDOUT, parser_plan) do |macro_name, formatter|
            case macro_name
               when "PRODUCTIONS"
                  formatter << %[@@productions = []]
                  parser_plan.productions.each do |production|
                     name          = quote_literal( make_general_name(production.label) )
                     name_number   = production.label_number
                     node_type     = quote_symbol( production.name )
                     symbol_count  = production.symbols.length
                     slot_mappings = []
                     asn_class     = asn_lookup.nil? ? "nil" : make_class_name(asn_lookup[production.label])

                     production.slot_mappings.each do |index, slot_name|
                        slot_mappings << "#{index} => #{quote_symbol(slot_name.intern)}"
                     end

                     formatter << %[]
                     formatter << %[#]
                     formatter << %[# Reducer for: #{production.to_s}]
                     formatter << %[]
                     formatter << %[@@productions << Productions.new( #{name}, #{name_number}, #{node_type}, #{symbol_count}, {#{slot_mappings.join(", ")}}, #{asn_class} )]
                     formatter << %[]
                  end
                  
               when "STATES"
                  # parser_plan.state_table.each do |state|
                  #    generate_state( state, formatter )
                  # end
                  
               else
                  formatter << macro_name
            end
         end
      end
      
      
      
      #
      # generate_state()
      #  - generates the parser routine for entering a state
      
      def generate_state( state, formatter )
         
         #
         # Group the actions.
         
         terminal_actions     = {}
         non_terminal_actions = {}
         
         state.actions.each do |symbol, action|
            if action.is_a?(Plan::Actions::Goto) then
               non_terminal_actions[symbol] = action
            else
               terminal_actions[symbol] = action
            end
         end
            
            
         #
         # Generate the function.
            
         description = ""
         state.display( description )
         
         generate_function( "perform_state_#{state.state_number}", description, formatter ) do

            #
            # Generate the terminals processing for the state.
            
            formatter << %[]
            formatter << %[#]
            formatter << %[# If there is nothing on deck, we are processing lookahead.]
            formatter << %[]
            formatter << %[if @on_deck.nil? then]
            formatter.indent do
               formatter << %[next_token = la( 1, #{state.state_number} )]
               formatter << %[token_type = next_token.nil? ? nil : next_token.type]
               formatter << %[]
               if terminal_actions.empty? then
                  formatter << "ERROR HANDLING HERE"
               else
                  formatter << %[case token_type]
                  terminal_actions.each do |symbol, action|
                     formatter << %[]
                     formatter << %[#]
                     formatter.indent( %[# ] ) do
                        formatter << %[Action analysis for lookahead #{quote_symbol(symbol)}]
                        formatter.indent( %[   ] ) do
                           state.explanations[symbol].each do |explanation|
                              formatter << explanation.to_s
                           end
                        end
                     end
                     formatter << %[]
                     formatter << %[when #{quote_symbol(symbol)}]
                     formatter.indent do
                        case action
                           when Plan::Actions::Shift
                              formatter << %[@node_stack  << consume(#{state.state_number})]
                              formatter << %[@state_stack << #{action.to_state.state_number}]
                           when Plan::Actions::Reduce
                              formatter << %[@on_deck = reduce_by_production_#{action.by_production.number}()]
                           when Plan::Actions::Accept
                              formatter << %[HOW DO WE ACCEPT?]
                           else
                              nyi "generation support for #{action.plan.name}"
                        end
                     end
                  end
                  formatter << %[]
                  formatter << %[#]
                  formatter << %[# Anything else is an error.]
                  formatter << %[]
                  formatter << %[else]
                  formatter << %[   ERROR HANDLING HERE]
                  formatter << %[end]
               end
            end
            
            #
            # Generate the non-terminals processing for the state.
            
            formatter << %[]
            formatter << %[#]
            formatter << %[# Otherwise, we are processing the Node on deck.]
            formatter << %[]
            formatter << %[else]
            formatter.indent do
               if non_terminal_actions.empty? then
                  formatter << %[# no op]
               else
                  formatter << %[@node_stack << @on_deck]
                  formatter << %[@on_deck    =  nil]
                  formatter << %[]
                  formatter << %[case @on_deck.type]
                  non_terminal_actions.each do |symbol, action|
                     formatter << %[when #{quote_symbol(symbol)}]
                     formatter.indent do
                        formatter << %[@state_stack << #{action.to_state.state_number}]
                     end
                  end
                  formatter << %[end]
               end
            end
            
            #
            # Finish up.
            
            formatter << %[end]
         end
      end
      
    
    
      
   end # TreeOrientedGenerator
   
   
   
   
   

end  # module Ruby
end  # module CodeGeneration
end  # module Rethink
