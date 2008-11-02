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
require "#{RCC_LIBDIR}/languages/grammar/grammar_builder.rb"
require "#{RCC_LIBDIR}/model/model.rb"


module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class ModelBuilder
 #  - builds an RCC::Model::System from an AST parsed from a grammar source file

   class ModelBuilder
      
      #
      # ::build()
      #  - given an AST of a grammar source file, returns a Model::System or an error report
      
      def self.build( ast )
         builder = new()
         return builder.build_model( ast )
      end
      
      Node  = RCC::Scanner::Artifacts::Node
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @builders = Util::OrderedHash.new()    # name => GrammarBuilder
      end



      #
      # build_model()
      #  - given a AST of a grammar source file, returns a Model::Grammar or an error report
      
      def build_model( system_spec )
         assert( system_spec.type == "RCC.system_spec", "Um, perhaps you meant to pass a system_spec AST?" )
         
         #
         # Pass 1: load up all the GrammarBuilders so that all names can be verified.
         
         system_spec.grammar_specs.each do |grammar_spec|
            if @builders.member?(grammar_spec.name.text) then
               nyi( "error handling for duplicate grammar name" )
            else
               @builders[grammar_spec.name.text] = GrammarBuilder.new( grammar_spec, self )
            end
         end
         
         
         #
         # Pass 2: build the Model and return it.
         
         @system = Model::System.new()
         @builders.each do |builder|
            @system.add_grammar( builder.build_model() )
         end
         
         return @system
      end
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
