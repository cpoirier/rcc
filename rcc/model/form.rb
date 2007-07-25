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
require "rcc/model/form_elements/terminal.rb"

module RCC
module Model
   
 
 #============================================================================================================================
 # class Form
 #  - a single form of a Rule

   class Form 
      
      PROPERTY_NAMES = { 
         "prec"  => :precedence,    "precedence"    => :precedence, 
         "assoc" => :associativity, "associativity" => :associativity 
      }
      
      PROPERTY_CONSTRAINTS = {
         :associativity => ["left", "right", "none"],
         :precedence    => proc { |grammar, rule, value| grammar.precedences.member?(value) }
      }
      
      PROPERTY_ERRORS = {
         :associativity => "expected one of (#{PROPERTY_CONSTRAINTS[:associativity].join(", ")})",
         :precedence    => "unrecognized rule/form name"
      }
      
      
      #
      # ::validate_property_name()
      #  - returns the property key if the supplied name is a valid property name, nil otherwise
      
      def self.validate_property_name( name )
         if PROPERTY_NAMES.member?(name) then
            return PROPERTY_NAMES[name]
         else
            return false
         end
      end
      
      
      #
      # ::validate_property_value()
      #  - returns a clean value, or nil
      
      def self.validate_property_value( grammar, rule, name, value )
         clean = value
         valid = false
         
         if key = PROPERTY_NAMES[name] then
            if constraint = PROPERTY_CONSTRAINTS[key] then
               case constraint
                  when Array
                     valid = constraint.member?( value )
                  when Proc
                     valid = constraint.call( grammar, rule, value )
                  else
                     bug "what other kinds of constraints are there?"
               end
            end
         end
         
         return (valid ? clean : nil)
      end
      
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :rule            # The Rule we are a Form of
      attr_reader   :number          # The number of the declaration of this form within the rule
      attr_reader   :root_element    # The root SeriesElement in this Form
      attr_accessor :id_number       # The id number of this number within the grammar
      attr_accessor :precedence      # A number indicating the precedence of this Form in relation to other Forms
      attr_reader   :label           # The Form label, if specified
      
      def initialize( root_element, rule, number, label, properties )
         @root_element = root_element
         @rule         = rule
         @number       = number
         @id_number    = nil
         @precedence   = nil
         @label        = label
         @properties   = properties
         @phrases      = nil
      end


      def eql?( rhs )
         return @id_number == @rhs.id_number
      end
      
      def hash()
         return @id_number.hash
      end
      

      #
      # associativity()
      #  - returns the associativity of this rule
      #  - defaults to "right", even for forms where associativity doesn't have much meaning
      
      def associativity()
         if @properties and @properties.member?(:associativity) then
            return @properties[:associativity]
         else
            return "right"
         end
      end
      

      #
      # precedence_equivalent()
      
      def precedence_equivalent()
         return @properties[:precedence]
      end
      
      
      #
      # phrases()
      #  - returns an array of Phrases of Symbols, one for each potential combination that would match
      #    this Form
      
      def phrases()
         @phrases = @root_element.phrases if @phrases.nil?
         return @phrases
      end
      
      





    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
        return "#{@rule.name} => #{@root_element}"
      end

      def display( stream, indent = "" )
         properties = []
         properties << "label:#{@label}" if @label
         properties << "assoc:#{@properties[:associativity]}" if @properties.member?(:associativity)
         properties << "prec:#{@precedence}"
         
         stream << indent << "#{@number} => " << @root_element.to_s.ljust(60) << "   {" << properties.join("; ") << "}\n"
      end
      
   end # Form
   







end  # module Model
end  # module Rethink
