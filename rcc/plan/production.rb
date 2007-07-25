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
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :rule_name
      attr_reader :name
      attr_reader :symbols
      attr_reader :associativity
      attr_reader :precedence
      attr_reader :form_id

      def initialize( rule_name, symbol_phrase, associativity, precedence, form_id, form = nil )
         type_check( symbol_phrase, "RCC::Model::Phrase" )
         
         @rule_name     = rule_name
         @name          = rule_name.intern
         @symbols       = symbol_phrase.symbols.collect {|model| Plan::Symbol.new(model.name, model.terminal?) }
         @associativity = associativity
         @precedence    = precedence
         @form_id       = form_id
         @form          = form
      end

    
      def to_s()
         return "#{@rule_name} => #{@inputs}"
      end



      
   end # Production
   





end  # module Plan
end  # module Rethink
