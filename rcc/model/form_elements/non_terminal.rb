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
require "rcc/model/form_elements/symbol.rb"
require "rcc/model/form.rb"

module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class NonTerminal
 #  - a descriptor of a literal or symbol token to be read

   class NonTerminal < Symbol
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :rule_name

      def initialize( rule_name )
         super( rule_name.intern )
         @rule_name = rule_name
      end
      
      
      def non_terminal?()
         return true
      end
      
      
      def ==( rhs )
         return @rule_name == rhs.rule_name
      end
      
      

      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def display( stream, indent = "" )
         if @slot_name.nil? then
            stream << indent << "NonTerminal #{@rule_name}\n"
         else
            stream << indent << "NonTerminal #{@rule_name} as #{@slot_name}\n"
         end
      end
      
   
      
      
   end # NonTerminal
   


end  # module FormElements
end  # module Model
end  # module Rethink
