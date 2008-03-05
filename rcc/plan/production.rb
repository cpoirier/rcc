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
require "#{$RCCLIB}/plan/symbol.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class Production
 #  - a single compiled Form, ready for use in the Plan

   class Production
      
      
      def self.start_production( start_rule_name )
         symbols = [Plan::Symbol.new(start_rule_name.intern, false), Plan::Symbol.end_of_input]
         return new( 0, start_rule_name, start_rule_name, 0, symbols, "right", -1, nil )
      end
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :number
      attr_reader   :rule_name
      attr_reader   :grammar_name
      attr_reader   :name
      attr_reader   :label                  # The label by which this Production is known for CST/AST purposes
      attr_reader   :label_number           # The number within all Productions that share this label
      attr_reader   :symbols
      attr_reader   :slots                  # A slot name or nil for each Symbol
      attr_reader   :associativity          # nil, :left, :right, or :none
      attr_reader   :precedence
      attr_reader   :ignore_conflicts
      attr_reader   :form_id                # Unique within the Grammar
      attr_reader   :form_number            # Unique within the Form
      attr_accessor :ast_class

      def initialize( number, grammar_name, rule_name, symbols, slots, associativity, ast_class, minimal_phrasing = true )
         @number           = number
         @grammar_name     = grammar_name
         @rule_name        = rule_name
         @name             = rule_name.intern
         @symbols          = symbols
         @slots            = slots
         @associativity    = associativity
         @ast_class        = ast_class
         @minimal_phrasing = minimal_phrasing
      end
      
      
      def length()
         return @symbols.length
      end
      
      
      #
      # minimal_phrasing?()
      #  - if true, this Production represents a simplest phrasing of the Form (ie. no optional tokens)
      
      def minimal_phrasing?()
         return @minimal_phrasing
      end
      
      
      def to_s()
         return "#{@rule_name} => #{@symbols.join(" ")}"
      end

      def ==( rhs )
         return @number == rhs.number
      end
      
      
      def display( stream = $stdout )
         stream.puts "#{@grammar_name}:#{@rule_name} =>"
         stream.indent do
            length().times do |i|
               if @symbols[i].is_an?(Array) then
                  stream << @symbols[i].join("|")
               else
                  stream << @symbols[i]
               end
               
               stream.puts( @slots[i].nil? ? ", then discard" : ", store in #{@slots[i]}" )  
            end
         end
      end
      
      
   end # Production
   





end  # module Plan
end  # module RCC
