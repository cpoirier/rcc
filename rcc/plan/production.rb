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
require "rcc/plan/symbol.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class Production
 #  - a single compiled Form, ready for use in the Plan

   class Production
      
      
      def self.start_production( start_rule_name )
         symbols = [Plan::Symbol.new(start_rule_name.intern, false), Plan::Symbol.end_of_input]
         return new( 0, start_rule_name, symbols, "right", -1, nil )
      end
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :number
      attr_reader   :rule_name
      attr_reader   :name
      attr_reader   :symbols
      attr_reader   :associativity
      attr_reader   :precedence
      attr_reader   :ignore_conflicts
      attr_reader   :form_id
      attr_reader   :slot_mappings
      attr_accessor :ast_class

      def initialize( number, rule_name, symbols, associativity, form_id, form = nil )
         @number        = number
         @rule_name     = rule_name
         @name          = rule_name.intern
         @symbols       = symbols
         @associativity = associativity
         @form_id       = form_id
         @form          = form
         @slot_mappings = {}
         @ast_class     = nil
         
         #
         # Map the slots for our Symbols.
         
         @symbols.each_index do |index|
            unless (slot = symbols[index].slot_name).nil?
               @slot_mappings[index] = slot
            end
         end
      end

    
      def to_s()
         return "#{@rule_name} => #{@symbols.join(" ")}"
      end


      
   end # Production
   





end  # module Plan
end  # module Rethink
