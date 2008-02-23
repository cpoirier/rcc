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
require "#{$RCCLIB}/model/rule.rb"
require "#{$RCCLIB}/model/precedence_table.rb"



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

      attr_writer :start_rule_name      # The name of the first rule in this Grammar
      attr_reader :ignore_terminals     # The names of any Terminals the lexer should eat
      attr_writer :enable_backtracking  # If true, backtracking will be used, where necessary, to handle conflicts

      attr_reader :state_table          # An Array of States for all states in the Grammar
      attr_reader :precedence_table     # A PrecedenceTable, showing rule precedence for shift/reduce conflicts
      

      def initialize( name )
         @name                = name
         @start_rule_name     = nil
         @ignore_terminals    = []
         @enable_backtracking = false
                            
         @strings = Util::OrderedHash.new()
         @groups  = Util::OrderedHash.new()
         @rules   = Util::OrderedHash.new()
      end
      
      
      #
      # name_defined?()
      
      def name_defined?( name )
         return (@strings.member?(name) || @groups.member?(name) || @rules.member?(name))
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    
      
      #
      # add_string()
      #  - adds a string definition (ExpressionForm of SparseRanges) to the Grammar
      
      def add_string( name, form )
         type_check( form, Util::ExpressionForms::ExpressionForm )
         assert( !name_defined?(name), "name [#{name}] is already in use" )
         
         @strings[name] = form
      end
      
      
      #
      # add_group()
      #  - adds a Group to the Grammar
      
      def add_group( name, group )
         type_check( group, Group )
         assert( !name_defined?(name), "name [#{name}] is already in use" )
         
         @groups[name] = group
      end
      
      
      #
      # add_rule()
      #  - adds a Rule to the Grammar
      
      def add_rule( rule )
         type_check( rule, Rule )
         assert( !name_defined?(rule.name), "name [#{rule.name}] is already in use" )
         
         @rules[rule.name] = rule
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
      # start_rule_name()
      #  - returns the name of the start rule for the Grammar
      
      def start_rule_name()
         if @start_rule_name.nil? then
            return nil if @rules.empty?
            return @rules[0].name
         else
            return @start_rule_name
         end
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
