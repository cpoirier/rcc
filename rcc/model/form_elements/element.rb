#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

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

      attr_accessor :label
      
      def initialize()         
         @label = nil
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
      # prep_slots()
      #  - maps out the slots that have been assigned or that we will be assigning

      def prep_slots( label_counts, slot_counts )
         each_element() do |element|
            element.prep_slots( label_counts, slot_counts )
         end
      end
      
      
      #
      # assign_slots()
      #  - assign slot names to the Symbols in the Rule
      #  - slot_counts contains a map of slot names to total use of the slot in the Rule
      #  - slot_tracks contains a map of slot names to last used index for that slot
      
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
      
      def phrases( label = nil )
         bug "you must override Element::phrases()"
      end

      
   end # Element
   


end  # module FormElements
end  # module Model
end  # module Rethink


require "#{$RCCLIB}/model/form_elements/series_element.rb"
require "#{$RCCLIB}/model/form_elements/fork_element.rb"
require "#{$RCCLIB}/model/form_elements/optional_element.rb"
require "#{$RCCLIB}/model/form_elements/raw_terminal.rb"
require "#{$RCCLIB}/model/form_elements/named_terminal.rb"
require "#{$RCCLIB}/model/form_elements/non_terminal.rb"