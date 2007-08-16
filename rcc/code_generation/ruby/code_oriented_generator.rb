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
 # class CodeOrientedGenerator
 #  - code generator for Ruby output
 #  - generates a code-based parser, with all decisions and actions hardcoded

   class CodeOrientedGenerator < Generator
      
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
         STDERR.puts "THIS GENERATOR IS IN DEVELOPMENT AND IS NOT COMPLETE!!!!"
         # generate_lexer( parser_plan, output_directory )
         generate_parser( parser_plan, output_directory )
         STDERR.puts "THIS GENERATOR IS IN DEVELOPMENT AND IS NOT COMPLETE!!!!"
      end
   
   
   
   
   

    #---------------------------------------------------------------------------------------------------------------------
    # Parser Generation
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      #
      # generate_parser()
      #  - generates a Parser and all the related machinery
      
      def generate_parser( parser_plan, output_directory )
         
         #
         # We only build an AST-producing Parser if requested.
         
         ast_class_lookup = nil
         if @configuration.member?("build_ast") and @configuration["build_ast"] then
            ast_class_lookup = {}
            parser_plan.productions.each do |production|
               ast_class_lookup[production.label] = make_class_name(production.label)
            end
         end
         
         
         #
         # Process the template.
            
         fill_template("static_parser.rb", STDOUT, parser_plan) do |macro_name, formatter|
            case macro_name
               when "PRODUCTIONS"
                  parser_plan.productions.each do |production|
                     generate_reduce_function( production, formatter, ast_class_lookup )
                  end
                  
               when "STATES"
                  parser_plan.state_table.each do |state|
                     generate_state( state, formatter )
                  end
                  
               else
                  formatter << macro_name
            end
         end
      end
      
    
    
      
      #
      # generate_reduce_function()
      #  - generates the reduce function on the Parser for a single Plan::Production
      
      def generate_reduce_function( production, formatter, ast_class_lookup = nil )
         
         generate_function( "reduce_by_production_#{production.number}", "Reducer for:\n   #{production.to_s}", [], formatter ) do
            symbols_to_pop = production.symbols.length
            
            formatter << %[produced_node = nodes = nil]
            formatter << %[]
            formatter << %[#]
            formatter << %[# First up, pop off the requisite number of objects from the node stack.  We also discard the]
            formatter << %[# same number of items from the other stacks.  Note that, for production purposes, we want the]
            formatter << %[# nodes in oldest-to-newest order. ]
            formatter << %[]
            formatter << %[nodes = @node_stack.slice!(  -#{symbols_to_pop}..-1  )]
            formatter << %[        @state_stack.slice!( -#{symbols_to_pop}..-1  )]
            
            
            #
            # Build the parameter list for the fallback processor/ASN initializer.
            
            slot_parameters = []
            production.slot_mappings.each do |index, slot_name|
               slot_parameters << ":#{slot_name} => nodes[#{index}]"
            end
            
            
            #
            # If ast_lookup is nil, we are not building an AST.  Instead, we collect a user-supplied value in 
            # Tokens and Nodes only.  
            
            if ast_class_lookup.nil? then
               processor_name  = "process_#{make_general_name(production.label)}__production_#{production.label_number}"
               fallback_name   = "process_#{make_general_name(production.label)}"
               
               formatter << %[]
               formatter << %[#]
               formatter << %[# Build the production Node.]
               formatter << %[]
               formatter << %[produced_node = Node.new( #{quote_symbol(production.name)} )]
               formatter << %[]
               formatter << %[#]
               formatter << %[# If the user has defined a processor for this production, call it and save the result in the Node.]
               formatter << %[]
               formatter << %[if method_defined?(#{quote_literal(processor_name)}) then]
               formatter << %[   produced_node.value = #{processor_name}( *nodes )]
               formatter << %[elsif method_defined?(#{quote_literal(fallback_name)}) then]
               formatter << %[   produced_node.value = #{fallback_name}( #{slot_parameters.join(", ")} )]
               formatter << %[end]
               
            #
            # Otherwise, we are building an AST.  
            
            else
               asn_name        = ast_class_lookup[production.label]
               processor_name  = "process_#{make_general_name(production.label)}"
               
               formatter << %[]
               formatter << %[#]
               formatter << %[# Build the production Node.]
               formatter << %[]
               formatter << %[produced_node = #{asn_name}.new( #{slot_parameters.join(", ")} )]
               formatter << %[]
               formatter << %[#]
               formatter << %[# If the user has defined a processor for this ASN, call it.]
               formatter << %[]
               formatter << %[if method_defined?(#{quote_literal(processor_name)}) then]
               formatter << %[   #{processor_name}( produced_node )]
               formatter << %[end]
            end
            

            formatter << %[]
            formatter << %[#]
            formatter << %[# Return the produced Node.]
            formatter << %[]
            formatter << %[return produced_node]
            
         end
      end
      
      
      #
      # generate_state()
      #  - generates the parser routine for entering a state
      
      def generate_state( state, formatter )
         # 
         # #
         # # Group the actions.
         # 
         # terminal_actions     = {}
         # non_terminal_actions = {}
         # 
         # state.actions.each do |symbol, action|
         #    if action.is_a?(Plan::Actions::Goto) then
         #       non_terminal_actions[symbol] = action
         #    else
         #       terminal_actions[symbol] = action
         #    end
         # end
         #    
         #    
         # #
         # # Generate the function.
         #    
         # description = ""
         # state.display( description )
         # 
         # generate_function( "perform_state_#{state.number}", description, formatter ) do
         # 
         #    #
         #    # Generate the terminals processing for the state.
         #    
         #    formatter << %[]
         #    formatter << %[#]
         #    formatter << %[# If there is nothing on deck, we are processing lookahead.]
         #    formatter << %[]
         #    formatter << %[if @on_deck.nil? then]
         #    formatter.indent do
         #       formatter << %[next_token = la( 1, #{state.number} )]
         #       formatter << %[token_type = next_token.nil? ? nil : next_token.type]
         #       formatter << %[]
         #       if terminal_actions.empty? then
         #          formatter << "ERROR HANDLING HERE"
         #       else
         #          formatter << %[case token_type]
         #          terminal_actions.each do |symbol, action|
         #             formatter << %[]
         #             formatter << %[#]
         #             formatter.indent( %[# ] ) do
         #                formatter << %[Action analysis for lookahead #{quote_symbol(symbol)}]
         #                formatter.indent( %[   ] ) do
         #                   state.explanations[symbol].each do |explanation|
         #                      formatter << explanation.to_s
         #                   end
         #                end
         #             end
         #             formatter << %[]
         #             formatter << %[when #{quote_symbol(symbol)}]
         #             formatter.indent do
         #                case action
         #                   when Plan::Actions::Shift
         #                      formatter << %[@node_stack  << consume(#{state.number})]
         #                      formatter << %[@state_stack << #{action.to_state.number}]
         #                   when Plan::Actions::Reduce
         #                      formatter << %[@on_deck = reduce_by_production_#{action.by_production.number}()]
         #                   when Plan::Actions::Accept
         #                      formatter << %[HOW DO WE ACCEPT?]
         #                   else
         #                      nyi "generation support for #{action.plan.name}"
         #                end
         #             end
         #          end
         #          formatter << %[]
         #          formatter << %[#]
         #          formatter << %[# Anything else is an error.]
         #          formatter << %[]
         #          formatter << %[else]
         #          formatter << %[   ERROR HANDLING HERE]
         #          formatter << %[end]
         #       end
         #    end
         #    
         #    #
         #    # Generate the non-terminals processing for the state.
         #    
         #    formatter << %[]
         #    formatter << %[#]
         #    formatter << %[# Otherwise, we are processing the Node on deck.]
         #    formatter << %[]
         #    formatter << %[else]
         #    formatter.indent do
         #       if non_terminal_actions.empty? then
         #          formatter << %[# no op]
         #       else
         #          formatter << %[@node_stack << @on_deck]
         #          formatter << %[@on_deck    =  nil]
         #          formatter << %[]
         #          formatter << %[case @on_deck.type]
         #          non_terminal_actions.each do |symbol, action|
         #             formatter << %[when #{quote_symbol(symbol)}]
         #             formatter.indent do
         #                formatter << %[@state_stack << #{action.to_state.number}]
         #             end
         #          end
         #          formatter << %[end]
         #       end
         #    end
         #    
         #    #
         #    # Finish up.
         #    
         #    formatter << %[end]
         # end
      end
      
    
    
      
   end # CodeOrientedGenerator
   
   
   
   
   

end  # module Ruby
end  # module CodeGeneration
end  # module Rethink
