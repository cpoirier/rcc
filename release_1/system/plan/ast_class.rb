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
 # class ASTClass
 #  - plan for an AST classes that can be built from our Rules and Forms

   class ASTClass
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      attr_reader :slots
      attr_reader :transformations
      
      def initialize( name )
         @name            = name
         @slots           = []
         @transformations = []
      end
      
      def define_slot( name, bug_if_duplicate = true )
         bug( "you cannot redefine slot [#{name}]" ) if bug_if_duplicate and @slots.member?(name)
         @slots << name unless @slots.member?(name)
      end
      
      def display( stream = $stdout )
         stream.puts "#{@name} slots:"
         stream.indent do
            @slots.each do |slot|
               stream.puts slot
            end
         end
      end
      
   end # ASTClass
   





end  # module Plan 
end  # module RCC
