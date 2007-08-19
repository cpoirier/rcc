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
require "#{$RCCLIB}/model/form_elements/element.rb"

module RCC
module Model
module FormElements

 
 #============================================================================================================================
 # class Symbol
 #  - the basic Elements that Form Rules

   class Symbol < Element
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      attr_reader :slot
      
      def initialize( name )
         @name = name
         @slot = nil
      end
      
      def terminal?()
         return false
      end
      
      
      def non_terminal?()
         return false
      end
      

      def hash()
         return @name.hash()
      end
      
      
      def eql?( rhs )
         if rhs.is_a?(FormElements::Symbol) then
            return @name == rhs.name
         else
            return @name == rhs
         end
      end
      
      
      def ==( rhs )
         return false unless rhs.is_a?(Symbol)
         return @name == rhs.name
      end


      def to_s()
         return @name.to_s
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Slot Assignment
    #---------------------------------------------------------------------------------------------------------------------
 
      
      #
      # potential_slot()
      #  - returns the base slot name you could use for this Symbol, taking into account any label already assigned
      
      def potential_slot()
         return @label.nil? ? @name.to_s : (@label == "ignore" ? nil : @label)
      end
      

      #
      # prep_slots()
      #  - maps out the label and slot names we'll be using, checks for invalid declarations
 
      def prep_slots( label_counts, slot_counts )
         label = @label
         slot  = self.potential_slot

         unless @label.nil? or @label == "ignore"
            label_counts[@label] = (label_counts.member?(@label) ? label_counts[@label] + 1 : 1)
         end
         
         unless slot.nil?
            slot_counts[slot] = (slot_counts.member?(slot) ? slot_counts[slot] + 1 : 1)
         end
      end
      
      
      #
      # assign_slots()
      #  - assign slot names to the NonTerminals in the Rule
      #  - label_counts contains a map of NonTerminal names to total use of the name in the Rule
      #  - label_tracks contains a map of NonTerminal names to last used index for that name
      
      def assign_slots( slot_counts, slot_tracks )
         slot = self.potential_slot()

         unless slot.nil?
            slot_tracks[slot] = (slot_tracks.member?(slot) ? slot_tracks[slot] + 1 : 1)

            if slot_counts[slot] == 1 then
               @slot = slot
            elsif slot_counts[slot] > 1 then
               # if slot.index("_").nil? then
               #    @slot = "#{slot}#{slot_tracks[slot]}"
               # else
                  @slot = slot + "_" + slot_tracks[slot].to_s
               # end
            end
         end
      end
      
    
      
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Plan construction
    #---------------------------------------------------------------------------------------------------------------------
    
    
      #
      # phrases()
      #  - produce an array of Forms representing all the forms of this Series
      
      def phrases( label = nil )
         @label = label if @label.nil?
         return [ Model::Phrase.new(self) ]
      end
      
      
      
    
   end # Symbol
   


end  # module FormElements
end  # module Model
end  # module Rethink


require "#{$RCCLIB}/model/phrase.rb"