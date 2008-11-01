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
      attr_reader :state_table       # Our States, in convenient table form
      attr_reader :ast_classes       # Our ASTClasses, in declaration order

      def initialize( master_plan, name, state_table )         
         @master_plan         = master_plan
         @name                = name
         @state_table         = state_table
         @ast_classes         = master_plan.ast_plans[name]
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




