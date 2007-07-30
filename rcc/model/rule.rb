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
require "rcc/model/form_elements/element.rb"
require "rcc/util/recursion_loop_detector.rb"

module RCC
module Model

 
 #============================================================================================================================
 # class Rule
 #  - a rule from the grammar

   class Rule
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name       # The name of this rule
      attr_reader :symbol     # The NonTerminal of this rule
      attr_reader :id_number  # The id number of this rule within the entire grammar
      attr_reader :forms      # The Forms in this Rule (this is where the real data is)

      def initialize( name, number, grammar )
         @name    = name
         @symbol  = FormElements::NonTerminal.new( name )
         @number  = number
         @grammar = grammar
         @forms   = []
      end
      
      
      #
      # create_form()
      #  - creates one a Form in the rule
      
      def create_form( root_element, label = nil, properties = {} )
         bug( "you cannot create new Forms after calling first_and_follow_sets()!" ) unless @first_and_follow_sets.nil?
         
         form = Form.new( root_element, self, @forms.length, label, properties )
         @forms << form
         
         @grammar.add_form( form )
      end
      
      
      #
      # assign_slots()
      #  - assign slot names to the NonTerminals in the Rule
      
      def assign_slots()
         slot_counts = {}
         slot_tracks = {}
         
         @root_element.count_slots( slot_counts )
         @root_element.assign_slots( slot_counts, slot_tracks )
      end



      




    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Rule #{@name}"
      end

      def display( stream, indent = "" )
         stream << indent << "Rule #{@name}\n"
         
         @forms.each do |form|
            form.display( stream, indent + "  " )
         end
      end
      
   end # Rule
   


end  # module Model
end  # module Rethink
