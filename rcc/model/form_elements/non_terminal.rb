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
    # Slot Assignment
    #---------------------------------------------------------------------------------------------------------------------
 
      
      #
      # count_slots()
      #  - maps out the slot names we'll be using
 
      def count_slots( slot_counts )
         if slot_counts.member?(@rule_name) then
            slot_counts[@rule_name] += 1
         else
            slot_counts[@rule_name] = 1
         end
      end
      
      
      #
      # assign_slots()
      #  - assign slot names to the NonTerminals in the Rule
      #  - slot_counts contains a map of NonTerminal names to total use of the name in the Rule
      #  - slot_tracks contains a map of NonTerminal names to last used index for that name
      
      def assign_slots( slot_counts, slot_tracks )
         if slot_tracks.member?(@rule_name) then
            slot_tracks[@rule_name] += 1
         else
            slot_tracks[@rule_name] = 1
         end
         
         if slot_counts[@rule_name] == 1 then
            @slot_name = @rule_name
         elsif slot_counts[@rule_name] > 1 then
            @slot_name = @rule_name + "_" + slot_tracks[@rule_name].to_s
         else
            bug( "who didn't call assign_slots with the hash built by count_slots?" )
         end
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
