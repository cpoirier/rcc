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
require "#{$RCCLIB}/model/rule.rb"
require "#{$RCCLIB}/model/precedence_table.rb"
require "#{$RCCLIB}/plan/lexer_plan.rb"
require "#{$RCCLIB}/plan/parser_plan.rb"
require "#{$RCCLIB}/languages/grammar/loader.rb"



module RCC
module Model

 
 #============================================================================================================================
 # class Grammar
 #  - the master representation of the user's grammar description
 #  - can be manipulated directly from code, or loaded from a text file

   class Grammar
      
      #
      # ::load_from_file()
      #  - loads the Grammar from a file on disk
      
      def self.load_from_file( descriptor, path )
         return RCC::Languages::Grammar::Loader::load_from_file( descriptor, path )
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name                 # Something that describes this grammar (might be a file path or anything else you want)
      attr_reader :definitions          # An OrderedHash of TerminalDefinitions and Strings defined in the Grammar
      attr_reader :rules                # An OrderedHash of every Rule in the Grammar
      attr_reader :forms                # An Array of every Form in the Grammar
      attr_reader :labels               # A Hash of name => (Rule, Form)
      attr_reader :state_table          # An Array of States for all states in the Grammar
      attr_reader :precedence_table     # A PrecedenceTable, showing rule precedence for shift/reduce conflicts
      attr_writer :start_rule_name      # The name of the first rule in this Grammar
      attr_reader :ignore_terminals     # The names of any Terminals the lexer should eat
      attr_writer :enable_backtracking  # If true, backtracking will be used, where necessary, to handle conflicts
      

      def initialize( name )
         @name                = name
         @start_rule_name     = nil
         @ignore_terminals    = []
         @enable_backtracking = false
                            
         @definitions         = Util::OrderedHash.new()
         @rules               = Util::OrderedHash.new()
         @forms               = []
         @labels              = {}
         @precedence_table    = PrecedenceTable.new()
      end
      
      def backtracking_enabled?()
         return @enable_backtracking
      end
      
      
      
      #
      # add_terminal_definition()
      #  - adds a Terminal to the definitions list
      #  - it is safe to define identical symbols as long as they are anonymous
      
      def add_terminal_definition( descriptor )
         if descriptor.name then
            nyi( "error handling for duplicate descriptor name" ) if @definitions.member?(descriptor.name)
            @definitions[descriptor.name] = descriptor
         else
            @definitions[@definitions.length] = descriptor
         end
      end
      
      
      #
      # create_rule()
      #  - creates a Rule and returns it
   
      def create_rule( name )
         nyi( "error handling for duplicate rule name" ) if @rules.member?(name)
         nyi( "error handling for duplicate rule name" ) if @labels.member?(name)
         nyi( "error handling for naming conflict"     ) if @definitions.member?(name)
         
         @rules[name]  = rule = Model::Rule.new( name, @rules.length, self )
         @labels[name] = rule
         
         return rule
      end
      
      
      #
      # add_form()
      #  - Forms are created via Rules, and then added here
      
      def add_form( form )
         nyi( "error handling for duplicate form labels" ) if !form.label.nil? and @labels.member?(form.label)
         
         #
         # Assign the form a unique number and add it to the Grammar.
         
         form.id_number = @forms.length
         @forms << form
         
         #
         # Index the name, if there is one
         
         @labels[form.label] = form unless form.label.nil?
      end
      
      
      
      #
      # compile_plan()
      #  - returns a Plan::ParserPlan version of this Grammar
      
      def compile_plan()
         return Plan::ParserPlan.build( self )
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
         return "Grammar #{@name}"
      end

      def display( stream = $stdout )
         stream << "Grammar #{@name}\n"
         stream.indent do
            @rules.each do |rule|
               rule.display( stream )
            end
         end
      end
      
   
      
   end # Grammar
   


end  # module Model
end  # module RCC
