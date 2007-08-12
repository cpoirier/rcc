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
         
         #
         # We only build an AST-producing Parser if requested.
         
         ast_class_lookup = nil
         if true or (@configuration.member?(:build_ast) and @configuration[:build_ast]) then
            ast_class_lookup = {}
            parser_plan.ast_classes.each do |name, ast_class|
               ast_class_lookup[name] = make_class_name(name) + "Node" unless ast_class_lookup.member?(name)
            end
         end
         
         # generate_parser( parser_plan, ast_class_lookup, output_directory )
         generate_ast_classes( parser_plan, ast_class_lookup, output_directory ) unless ast_class_lookup.nil?
      end
   
   
   
   
   

    #---------------------------------------------------------------------------------------------------------------------
    # Parser Generation
    #---------------------------------------------------------------------------------------------------------------------
    
    private
    
      #
      # generate_parser()
      #  - generates a Parser and all the related machinery
      
      def generate_parser( parser_plan, ast_class_lookup, output_directory )
         fill_template("tree_based_parser.rb", STDOUT, parser_plan) do |macro_name, formatter|
            case macro_name
               when "PRODUCTIONS"
                  generate_productions( parser_plan, ast_class_lookup, formatter )

               when "STATES"
                  generate_states( parser_plan, formatter )
                  
               when "REDUCE_PROCESSING"
                  if ast_class_lookup.nil? then
                     formatter.comment_block %[Build the production Node.]
                     formatter << %[produced_node = Node.new( production.node_type )]
                     
                     formatter.comment_block %[If the user has defined a processor for this production, call it and save the result in the Node.]
                     formatter << %[if method_defined?(production.production_processor_name) then]
                     formatter << %[   produced_node.value = send( production.production_processor_name, *nodes )]
                     formatter << %[elsif method_defined?(production.processor_name) then]
                     formatter << %[   produced_node.value = send( production.processor_name, production.enslot_nodes(nodes) )]
                     formatter << %[end]
                  else
                     formatter.comment_block %[Build the production Node.]
                     formatter << %[ast_class = production.ast_class]
                     formatter << %[ast_class = Local.const_get(production.ast_class.name) if defined? Local and Local.class == Module and Local.const_defined?(production.ast_class.name)]
                     formatter << %[]
                     formatter << %[produced_node = ast_class.new( production.enslot_nodes(nodes) )]

                     formatter.comment_block %[If the user has defined a processor for this ASN, call it.]
                     formatter << %[if method_defined?(production.processor_name) then]
                     formatter << %[   send( production.processor_name, produced_node )]
                     formatter << %[end]
                  end
                  
               else
                  formatter << macro_name
            end
         end
      end



      #
      # generate_productions()
      #  - generates the Production definitions
      
      def generate_productions( parser_plan, ast_class_lookup, formatter )
         formatter << %[@@productions = [nil]]
         parser_plan.productions.each do |production|
            name          = quote_literal( make_general_name(production.label) )
            name_number   = production.label_number
            node_type     = quote_symbol( production.name )
            symbol_count  = production.symbols.length
            slot_mappings = []
            asn_class     = ast_class_lookup.nil? ? "nil" : ast_class_lookup[production.label]

            production.slot_mappings.each do |index, slot_name|
               slot_mappings << "#{index} => #{quote_symbol(slot_name.intern)}"
            end

            formatter << %[]
            formatter << %[#]
            formatter << %[# Production #{production.number}: #{production.to_s}]
            formatter << %[]
            formatter << %[@@productions << Productions.new( #{name}, #{name_number}, #{node_type}, #{symbol_count}, {#{slot_mappings.join(", ")}}, #{asn_class} )]
            formatter << %[]
         end
      end
      
      
      
      #
      # generate_states()
      #  - generate the states and actions for this parser plan
      
      def generate_states( parser_plan, formatter )

         #
         # First, generate empty State objects for each state.  We'll need these as forward declarations.
         
         formatter.comment_block %[Generate empty states sufficient to our needs.  We'll add actions to them shortly.]
         formatter << %[@@states = []]
         formatter << %[#{parser_plan.state_table.length}.times { |i| @@states << State.new(i) }]

         formatter.comment_block %[All ShiftActions for a particular to-State are identical, so we'll reuse them.]
         formatter << %[@@shift_actions = []]
         formatter << %[#{parser_plan.state_table.length}.times { |i| @@goto_actions << ShiftAction.new( @@states[i] ) }]

         formatter.comment_block %[All ReduceActions for a particular Production are identical, so we'll reuse them.]
         formatter << %[@@reduce_actions = [nil]]
         formatter << %[#{parser_plan.productions.length}.times { |i| @@reduce_actions << ReduceAction.new(i)}]

         formatter.comment_block %[All GotoActions for a particular to-State are identical, so we'll reuse them.]
         formatter << %[@@goto_actions = []]
         formatter << %[#{parser_plan.state_table.length}.times { |i| @@goto_actions << GotoAction.new( @@states[i] ) }]
         
         formatter.blank_line
         
         
         #
         # Next, generate the Actions for each state.

         parser_plan.state_table.each do |state|
            
            #
            # Display the state description in a comment.

            formatter.comment_block do
               description = ""
               state.display( description )
               
               formatter << description
            end

            formatter.block( "begin", "end" ) do
               formatter << %[state = @@states[#{state.number}]]
               
               #
               # Group the actions for output: terminals and non-terminals.

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
               # Output the Actions and analysis for each terminal.
               
               terminal_actions.each do |symbol, action|
                  formatter.comment_block do
                     formatter << %[Action analysis for lookahead #{quote_symbol(symbol)}]
                     formatter.indent( %[   ] ) do
                        state.explanations[symbol].each do |explanation|
                           formatter << explanation.to_s
                        end
                     end
                  end
                  
                  formatter.indent( %[state.actions[#{quote_symbol(symbol)}] = ]) do
                     case action
                        when Plan::Actions::Shift
                           formatter << %[@@shift_actions[#{action.to_state.number}]]
                        when Plan::Actions::Reduce
                           formatter << %[@@reduce_actions[#{action.by_production.number}]]
                        when Plan::Actions::Accept
                           formatter << %[AcceptAction.new()]
                        else
                           nyi "generation support for #{action.class.name}"
                     end
                  end
               end
               
               #
               # Output the Actions for each non-terminal.  No analysis is necessary.
               
               unless non_terminal_actions.empty?
                  symbols       = []
                  state_numbers = []
                  non_terminal_actions.each do |symbol, action|
                     symbols       << quote_symbol(symbol)
                     state_numbers << action.to_state.number.to_s
                  end
               
                  formatter.comment_block %[Action for non-terminals is always Goto.]
                  formatter.columnate "state.actions[", symbols, "] = @@goto_actions[", state_numbers, "]"
               end
            end
            
            formatter.blank_line
            formatter.blank_line
         end
         
      end
    



    #---------------------------------------------------------------------------------------------------------------------
    # AST Class Generation
    #---------------------------------------------------------------------------------------------------------------------
    
    private
    
      #
      # generate_ast_classes()
      #  - generates all the AST classes for this parser plan
      #  - based on configuration, can use the generated base class or a user supplied subclass of that as base class
      
      def generate_ast_classes( parser_plan, ast_class_lookup, output_directory )
         general_base_class_name = @configuration.member?(:asn_base_class) ? @configuration[:asn_base_class] : "ASNode"
      
         fill_template("ast.rb", STDOUT, parser_plan) do |macro_name, formatter|
            case macro_name
               when "ASNs"
                  parser_plan.ast_classes.each do |name, ast_class|
                     class_name      = ast_class_lookup[name]
                     base_class_name = ast_class.parent_class.nil? ? general_base_class_name : ast_class_lookup[ast_class.parent_class.name]

                     4.times { formatter.blank_line }
                     formatter << %[#============================================================================================================================]
                     formatter << %[# class #{class_name}]
                     formatter << %[#  - Abstract Syntax Tree Node]
                     formatter << %[]
                     
                     formatter.indent( "  " ) do
                        formatter.block( "class #{class_name} < #{base_class_name}", "end" ) do

                           if ast_class.parent_class.nil? then
                              generate_function( "initialize", nil, ["slots"], formatter ) do
                                 formatter << %[super( #{quote_symbol(ast_class.name.intern)}, slots )]
                              end
                           else
                              generate_function( "initialize", nil, ["elements"], formatter ) do 
                                 formatter << %[super( [#{ast_class.slots.collect{|name| quote_symbol(name.intern)}.join(", ")}] )]
                                 ast_class.slots.each do |slot|
                                    slot_name = quote_symbol(slot.intern)
                                    formatter << %[self.slots[#{slot_name}] = elements[#{slot_name}]]
                                 end
                              end
                           end
                           
                        end
                     end
                  end
               
               else
                  formatter << macro_name
            end
         end
      end
      
          
      
   end # TreeOrientedGenerator
   
   
   
   
   

end  # module Ruby
end  # module CodeGeneration
end  # module Rethink
