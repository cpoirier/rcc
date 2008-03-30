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

module RCC
module Plan

 
 #============================================================================================================================
 # class ParserPlan
 #  - a plan for a backtracking LALR(1) parser that implements a Model::Grammar
 #  - whereas the Model Grammar deals in Rules and Forms, we deal in Productions; we both deal in Symbols

   class ParserPlan
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :master_plan       # The MasterPlan
      attr_reader :name              # The name of the Grammar from which this Plan was built
      attr_reader :lexer_plan        # A LexerState that describes how to lex the Grammar; note that each State can produce a customization on this one
      attr_reader :state_table       # Our States, in convenient table form
      attr_reader :ast_classes       # Our ASTClasses, in declaration order

      def initialize( master_plan, name, state_table, enable_backtracking = false )         
         assert( master_plan.lexer_plans.member?(name), "why is there no LexerPlan for this ParserPlan [#{name}]?" )
         
         @master_plan         = master_plan
         @name                = name
         @state_table         = state_table
         @lexer_plan          = master_plan.lexer_plans[ name ]
         @ast_classes         = master_plan.get_ast_plan( name )
         @enable_backtracking = enable_backtracking
      end
      
      
      def non_terminal?( type )
         return false unless type.is_a?(::Symbol)
         return @production_sets.member?(type)
      end
      
      def non_terminals()
         return @production_sets.keys
      end
      
      
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Parser construction
    #---------------------------------------------------------------------------------------------------------------------


      #
      # compile_actions()
      #  - runs through all our State tables and builds Actions that can drive a compiler
      #  - optionally constructs explanations for conflict resolutions
      
      def compile_actions( estream = nil )
         duration = Time.measure do 
            @state_table.each do |state|
               duration = Time.measure do
                  state.compile_actions( @enable_backtracking, estream )
                  state.compile_customized_lexer_plan( @lexer_plan, estream )
               end
               
               estream.puts "Action compilation for state #{state.number}: #{duration}s" if estream && $show_statistics && duration > 0.25
            end
         end
         
         estream.puts "Action compilation duration: #{duration}s" if estream && $show_statistics
         
         return self
      end



   
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Grammar #{@name}"
      end
      
      def display( stream ) # BUG: pass via ContextStream: complete = true, show_context = :reduce_determinants )
         stream << "States\n"
         stream.indent do 
            @state_table.each do |state|
               state.display( stream )
            end
         end
      end
      
   



      
   end # Grammar
   


end  # module Model
end  # module RCC




