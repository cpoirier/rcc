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
require "#{RCC_LIBDIR}/plan/symbol.rb"
require "#{RCC_LIBDIR}/scanner/artifacts/name.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class Production
 #  - a base class for things that describe how to produce Nodes during parsing

   class Production
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :number
      attr_reader   :name
      attr_reader   :symbols
      attr_accessor :master_plan

      def initialize( number, name, symbols, master_plan = nil )
         type_check( name, Scanner::Artifacts::Name )
         
         @number        = number
         @name          = name
         @symbols       = symbols
         @master_plan   = master_plan
      end
      
      def syntactic?()
         return false
      end
      
      def lexical?()
         return !syntactic?
      end
      
      alias rule_name name
      
      def signature()
         return @name.signature
      end
      
      def description( elide_grammar = nil )
         return @name.description( elide_grammar )
      end      

      
      def length()
         return @symbols.length
      end
      
      
      def to_s()
         return "#{@name.description} => #{@symbols.join(" ")}"
      end

      def ==( rhs )
         return @number == rhs.number
      end
      
      
      def display( stream = $stdout )
         stream.puts "#{@name} =>"
         stream.indent do
            length().times do |i|
               stream.puts( @symbols[i].description )
            end
         end
      end
      
      
   end # Production
   





end  # module Plan
end  # module RCC


require "#{RCC_LIBDIR}/plan/syntax_production.rb"
require "#{RCC_LIBDIR}/plan/token_production.rb"

