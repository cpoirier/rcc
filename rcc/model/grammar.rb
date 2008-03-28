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
require "#{$RCCLIB}/util/ordered_hash.rb"
require "#{$RCCLIB}/util/expression_forms/expression_form.rb"



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
      attr_reader :strings              # name => lexical pattern (ExpressionForm of SparseRange)
      attr_reader :groups               # name => Group
      attr_reader :rules                # name => Rule

      attr_reader :ignore_terminals     # The names of any Terminals the lexer should eat
      attr_writer :enable_backtracking  # If true, backtracking will be used, where necessary, to handle conflicts

      attr_reader :state_table          # An Array of States for all states in the Grammar
      
      attr_accessor :system

      def initialize( name )
         @name                = name
         @start_rule_name     = nil
         @ignore_terminals    = []
         @enable_backtracking = false
                            
         @strings = Util::OrderedHash.new()
         @rules   = Util::OrderedHash.new()
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
         return (@strings.member?(name) || @rules.member?(name))
      end
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # add_string()
      #  - adds a string definition (ExpressionForm of SparseRanges) to the Grammar
      
      def add_string( name, string_descriptor )
         type_check( string_descriptor, Elements::StringDescriptor )
         assert( !name_defined?(name), "name [#{name}] is already in use" )
         
         @strings[name] = string_descriptor
      end
      
      
      #
      # add_group()
      #  - adds a Group to the Grammar
      
      def add_group( group )
         type_check( group, Elements::Group )
         assert( !name_defined?(name), "name [#{name}] is already in use" )
         
         @rules[group.name] = group
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
      # backtracking_enabled?()
      #  - returns true if the Grammar should support backtracking
      
      def backtracking_enabled?()
         return @enable_backtracking
      end

      
      #
      # start_rule()
      #  - returns a RuleReference to the start rule for the Grammar
      
      def start_rule()
         return References::RuleReference.new( start_rule_name() )
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


require "#{$RCCLIB}/model/model.rb"
