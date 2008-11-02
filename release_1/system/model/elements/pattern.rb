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
module Model
module Elements

 
 #============================================================================================================================
 # class Pattern
 #  - describes a lexical string that can be produced by the Parser

   class Pattern
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name
      attr_reader :master_form

      def initialize( name, master_form )
         @name        = name
         @master_form = master_form
      end
      
      def display( stream = $stdout )
         stream.puts "string pattern #{@name}:"
         stream.indent do
            @master_form.display( stream )
         end
      end
      
      def tokenizeable?()
         return true
      end
      
      
   end # Pattern
   






 #============================================================================================================================
 # class Subpattern
 #  - represents a subpattern that has been factored out for repeating
 
   class Subpattern < Pattern
      
      Optional = Util::ExpressionForms::Optional
      Sequence = Util::ExpressionForms::Sequence
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :rule_form
      attr_reader :singular_form
      
      def initialize( name, singular_form )
         @singular_form = singular_form
         
         tree_side = Markers::Reference.new( name )
         rule_form = Sequence.new( Optional.new(tree_side), @singular_form )
         super( name, rule_form )
      end
      
      def tokenizeable?()
         return false
      end

   end # Subpattern
   
   
   
 
end  # module Elements
end  # module Model
end  # module RCC
