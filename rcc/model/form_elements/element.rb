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

module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class Element
 #  - an element in a rule

   class Element
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()         
      end
      
      
      #
      # each_element()
      #  - loops through each element in this element
      
      def each_element()
      end
    
    
    
      
    #---------------------------------------------------------------------------------------------------------------------
    # Slot assignment
    #---------------------------------------------------------------------------------------------------------------------

      
      #
      # count_slots()
      #  - maps out the slot names we'll be using

      def count_slots( slot_counts )
         each_element() do |element|
            element.count_slots( slot_counts )
         end
      end
      
      
      #
      # assign_slots()
      #  - assign slot names to the NonTerminals in the Rule
      #  - slot_counts contains a map of NonTerminal names to total use of the name in the Rule
      #  - slot_tracks contains a map of NonTerminal names to last used index for that name
      
      def assign_slots( slot_counts, slot_tracks )
         each_element() do |element|
            element.assign_slots( slot_counts, slot_tracks )
         end
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Plan construction
    #---------------------------------------------------------------------------------------------------------------------

      #
      # phrases()
      #  - produce an array of Forms representing all the forms of this Series
      
      def phrases()
         bug "you must override Element::phrases()"
      end

      
   end # Element
   


end  # module FormElements
end  # module Model
end  # module Rethink


require "rcc/model/form_elements/series_element.rb"
require "rcc/model/form_elements/fork_element.rb"
require "rcc/model/form_elements/optional_element.rb"
require "rcc/model/form_elements/raw_terminal.rb"
require "rcc/model/form_elements/named_terminal.rb"
require "rcc/model/form_elements/non_terminal.rb"