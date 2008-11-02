#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"

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




