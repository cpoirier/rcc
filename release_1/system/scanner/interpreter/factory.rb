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
require "#{RCC_LIBDIR}/scanner/artifacts/source.rb"
require "#{RCC_LIBDIR}/scanner/interpreter/parser.rb"


module RCC
module Scanner
module Interpreter

 
 #============================================================================================================================
 # class Factory
 #  - a factory to produce the correct equipment, given a few starting points

   class Factory
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_accessor :recovery_limit
      attr_reader   :parser_plan
      
      def initialize( parser_plan, recovery_limit = 3 )
         @parser_plan    = parser_plan
         @recovery_limit = 3
      end
      

      #
      # parse()
      #  - parses a file using machinery produced by this Factory
      
      def parse( descriptor, estream = nil, file = nil )
         return build_parser( descriptor, file ).parse( @recovery_limit, estream )
      end
      
      
      #
      # open_source()
      #  - returns a Source around your input
      
      def open_source( descriptor, file = nil )
         return descriptor if descriptor.is_a?(RCC::Scanner::Artifacts::Source)
         return RCC::Scanner::Artifacts::Source.open( descriptor, file )
      end
      
      
      #
      # build_parser()
      #  - returns a new Parser
      
      def build_parser( descriptor, file = nil )
         return RCC::Scanner::Interpreter::Parser.new( @parser_plan, open_source(descriptor, file) )
      end
      
      
   end # Factory
   





end  # module Interpreter
end  # module Scanner
end  # module RCC
