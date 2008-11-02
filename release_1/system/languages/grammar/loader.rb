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
require "#{RCC_LIBDIR}/languages/grammar/grammar.rb"
require "#{RCC_LIBDIR}/languages/grammar/model_builder.rb"
require "#{RCC_LIBDIR}/scanner/interpreter/factory.rb"

module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class Loader
 #  - loads a Grammar file from disk, using the best method available

   class Loader
      
      @@use_bootstrap_parser     = !File.exists?( "#{RCC_LIBDIR}/languages/grammar/parser/parser.rb" )
      @@bootstrap_parser_factory = nil
      
      def self.load_from_file( descriptor, path = nil )
         path = File.expand_path( descriptor ) if path.nil?
         
         if @@use_bootstrap_parser then
            initialize_bootstrap_parser() if @@bootstrap_parser_factory.nil?
            return @@bootstrap_parser_factory.parse( path )
         else
            nyi( "support for pre-built parser" )
         end
         
      end



    #---------------------------------------------------------------------------------------------------------------------
    # Bootstrapping
    #---------------------------------------------------------------------------------------------------------------------
    

      
    #---------------------------------------------------------------------------------------------------------------------
    # Bootstrapping
    #---------------------------------------------------------------------------------------------------------------------

      #
      # initialize_bootstrap_parser()
      #  - loads and initializes the bootstrap parser that will be used to load Grammars
      
      def self.initialize_bootstrap_parser( )
         duration = Time.measure do 
            system_model = ModelBuilder.build( Grammar.ast )
            master_plan  = system_model.compile_master_plan()
            parser_plan  = master_plan.compile_parser_plan( system_model.start_rule )

            @@bootstrap_parser_factory = RCC::Scanner::Interpreter::Factory.new( parser_plan )
         end
         
         puts "It took #{duration}s to build the RCC grammar"
         @@bootstrap_parser_factory
      end
      
   end # Loader
   


end  # module Grammar
end  # module Languages
end  # module RCC
