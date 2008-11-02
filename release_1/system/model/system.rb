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
require "#{RCC_LIBDIR}/util/ordered_hash.rb"
require "#{RCC_LIBDIR}/model/grammar.rb"
require "#{RCC_LIBDIR}/plan/master_plan.rb"


module RCC
module Model

 
 #============================================================================================================================
 # class System
 #  - a single system of Grammars

   class System
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :grammars
      
      def initialize()
         @grammars = Util::OrderedHash.new()    # name => Grammar
      end


      def add_grammar( grammar )
         type_check( grammar, Grammar )
         assert( !@grammars.member?(grammar.name), "name [#{grammar.name}] is already in use" )
         
         @grammars[grammar.name] = grammar
         grammar.system = self
      end
      
      
      def resolve( name )
         if name.grammar.nil? then
            @grammars.each do |grammar|
               return grammar.resolve(name) if grammar.name_defined?(name)
            end
         else
            return @grammars[name.grammar].resolve(name)
         end
         
         return nil
      end


      def start_rule()
         return @grammars[0].start_rule()
      end



    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    

      #
      # compile_master_plan()
      #  - returns a Plan::MasterPlan for this System of Grammars
      
      def compile_master_plan()
         return Plan::MasterPlan.build( self )
      end


   end # System



   


end  # module Model
end  # module RCC
