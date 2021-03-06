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
require "#{RCC_LIBDIR}/util/expression_forms/expression_form.rb"



module RCC
module Model

 
 #============================================================================================================================
 # class Grammar
 #  - the master representation of the user's grammar description

   class Grammar
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name                 # The name of the grammar within the set
      attr_reader :patterns             # name => Pattern
      attr_reader :groups               # name => Group
      attr_reader :rules                # name => Rule
      
      attr_accessor :system

      def initialize( name )
         type_check( name, String )
         
         @name                = name
         @start_rule_name     = nil
                            
         @patterns = Util::OrderedHash.new()
         @rules    = Util::OrderedHash.new()
         @groups   = Util::OrderedHash.new()
      end
      
      def start_rule_name=( name )
         assert( name_defined?(name), "start_rule [#{name}] not defined!" )
         @start_rule_name = name
      end
      
      def start_rule_name()
         return @start_rule_name.nil? ? @rules.order[0] : @start_rule_name
      end
      
      
      #
      # name_defined?()
      
      def name_defined?( name )
         return (@patterns.member?(name) || @rules.member?(name) || @groups.member?(name))
      end
      
      def resolve( name )
         return @patterns[name] if @patterns.member?(name)
         return @rules[name]    if @rules.member?(name)
         return @groups[name]   if @groups.member?(name)
         return nil
      end
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # add_pattern()
      #  - adds a Pattern to the Grammar
      
      def add_pattern( pattern )
         type_check( pattern, Elements::Pattern )
         assert( !name_defined?(name), "name [#{name}] is already in use" )
         
         @patterns[pattern.name] = pattern
      end
      
      
      #
      # add_group()
      #  - adds a Group to the Grammar
      
      def add_group( group )
         type_check( group, Elements::Group )
         assert( !name_defined?(name), "name [#{name}] is already in use" )
         
         @groups[group.name] = group
      end
      
      
      #
      # add_rule()
      #  - adds a Rule to the Grammar
      
      def add_rule( rule )
         type_check( rule, Elements::Rule )
         assert( !name_defined?(rule.name), "name [#{rule.name}] is already in use" )
         
         @rules[rule.name] = rule
      end
      
      
      #
      # add_element()
      
      def add_element( element )
         case element
            when Elements::Rule
               return add_rule( element )
            when Elements::Group
               return add_group( element )
            else
               nyi( nil, element.class.name )
         end
      end
      
      
      #
      # compile_plan()
      #  - returns a Plan::ParserPlan version of this Grammar
      
      def compile_plan()
         return Plan::ParserPlan.build( self )
      end
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Information
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # start_rule()
      #  - returns a RuleReference to the start rule for the Grammar
      
      def start_rule()
         return Markers::Reference.new( start_rule_name() )
      end
    
    
    
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "grammar #{@name}"
      end

      def display( stream = $stdout )
         stream << "grammar #{@name}\n"
         stream.indent do
            @rules.each do |rule|
               rule.display( stream )
            end
         end
      end
      
   
      
   end # Grammar
   


end  # module Model
end  # module RCC


require "#{RCC_LIBDIR}/model/model.rb"
