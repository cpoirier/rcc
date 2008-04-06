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
require "#{$RCCLIB}/plan/transformations/selector.rb"

module RCC
module Plan
module Transformations
 
 
 #============================================================================================================================
 # class SlotSelector
 #  - a selector that picks data from the named slot in a set of nodes

   class SlotSelector < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :slot_name
      
      def initialize( slot_name, target )
         super( target )
         @slot_name = slot_name
      end
      
      
      #
      # apply()
      #  - applies this selector to a node set, returning the resulting nodes
      
      def apply( nodes )
         results = []
         
         nodes.each do |node|
            if node.slot_filled?(@slot_name) then
               results.concat( [node[@slot_name]].flatten )
            end
         end
         
         return results.uniq
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << "@" << @slot_name
         super
      end
      
      
   end # SlotSelector
   


end  # module Transformations
end  # module Plan
end  # module RCC
