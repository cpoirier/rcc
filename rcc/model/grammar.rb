#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"
require "rcc/util/ordered_hash.rb"
require "rcc/model/rule.rb"
require "rcc/plan/lexer_plan.rb"
require "rcc/plan/parser_plan.rb"



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
         grammar = new( descriptor )
         
         require "rcc/model/loader.rb"
         File.open(path) do |file|
            loader = Loader.new( grammar )
            loader.load( file.read(), path )
         end
         
         return grammar
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :descriptor           # Something that describes this grammar (might be a file path or anything else you want)
      attr_reader :names                # A Hash of name => (Rule, Definition)
      attr_reader :definitions          # An OrderedHash of TerminalDefinitions and Strings defined in the Grammar
      attr_reader :rules                # An OrderedHash of every Rule in the Grammar
      attr_reader :forms                # An Array of every Form in the Grammar
      attr_reader :state_table          # An Array of States for all states in the Grammar
      attr_reader :precedences          # A Hash of label => precedence
      attr_reader :configuration        # A Hash of configuration flags

      def initialize( descriptor )
         @descriptor    = descriptor
         @configuration = {}
         
         @names         = {}
         @definitions   = Util::OrderedHash.new()
         @rules         = Util::OrderedHash.new()
         @forms         = []
         @precedences   = {}
      end
      
      
      #
      # add_terminal_definition()
      #  - adds a Terminal to the definitions list
      #  - it is safe to define identical symbols as long as they are anonymous
      
      def add_terminal_definition( descriptor )
         if descriptor.name then
            nyi( "error handling for duplicate descriptor name" ) if @definitions.member?(descriptor.name)
            @definitions[descriptor.name] = descriptor
            @names[descriptor.name]       = descriptor
         else
            @definitions[@definitions.length] = descriptor
         end
      end
      
      
      #
      # create_rule()
      #  - creates a Rule and returns it
   
      def create_rule( name )
         nyi( "error handling for duplicate rule name" ) if @rules.member?(name)
         nyi( "error handling for naming conflict"     ) if @definitions.member?(name)
         
         @rules[name] = rule = Model::Rule.new( name, @rules.length, self )
         return rule
      end
      
      
      #
      # add_form()
      #  - Forms are created via Rules, and then added here
      #  - resolves precedence links
      
      def add_form( form )
         
         #
         # Assign the form a unique number and add it to the Grammar.
         
         form.id_number = @forms.length
         @forms << form

         #
         # Set the Form precedence, either based on a reference to an existing Rule/Form, or
         # by defaulting to the current Form id_number.
         
         if form.precedence_equivalent then
            if number = @precedences[form.precedence_equivalent] then
               form.precedence = number
            else
               nyi( "error handling for missing precedence name #{form.precedence_equivalent}" )
            end
         else
            form.precedence = form.id_number
         end
         
         unless @precedences.member?(form.label) 
            @precedences[form.label] = form.precedence
         end
      end
      
      
      
      #
      # compile_plan()
      #  - returns a Plan::ParserPlan version of this Grammar
      
      def compile_plan()
         lexer_plan = Plan::LexerPlan.build( self )
         return Plan::ParserPlan.build( self, lexer_plan )
      end
      
      
      #
      # start_rule_name()
      #  - returns the name of the start rule for the Grammar
      
      def start_rule_name()
         if @configuration.member?("StartRule") then
            return @configuration["StartRule"]
         else
            return @rules[0].name
         end
      end

    
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Grammar #{@name}"
      end

      def display( stream, indent = "" )
         stream << indent << "Grammar #{@name}\n"
         @rules.each do |rule|
            rule.display( stream, indent + "   " )
         end
      end
      
   
      
   end # Grammar
   


end  # module Model
end  # module Rethink
