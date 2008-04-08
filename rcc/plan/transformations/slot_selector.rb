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
      #  - applies this selector to a node or set of nodes
      
      def apply( nodes )
         results = nil
         if nodes.is_an?(Array) then
            results  = []
         
            nodes.each do |node|
               next if node.token?
               if node.slot_filled?(@slot_name) then
                  results.concat node[@slot_name].to_a
               end
            end
            
            results.uniq!
         else
            results = nodes[@slot_name] if (!nodes.token? and nodes.slot_filled?(@slot_name))
         end
         
         return results
      end
      
      
      #
      # assign()
      
      def assign( search_nodes, result_nodes )
         return super unless target?

         update(search_nodes) do |node|
            node.define_slot( @slot_name, result_nodes )
         end
      end
      
      
      #
      # append()
      
      def append( search_nodes, result_nodes )
         return super unless target?
         
         update( search_nodes ) do |node|
            node.define_slot( @slot_name, node[@slot_name].to_a + result_nodes )
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << "@" << @slot_name
         super
      end
      


      #
      # update()
      #  - an internal routine that encapsulates the common functionality needed to
      #    use this Selector for update work
      
      def update( search_nodes )
         if has_target_predicate? then
            search_nodes.each do |node|
               if node.slot_filled?(@slot_name) then
                  unless @target_predicate.apply(node[@slot_name].to_a).empty?
                     yield( node )
                  end 
               end
            end
         else
            search_nodes.each do |node|
               yield( node )
            end
         end
      end
      
   end # SlotSelector
   


end  # module Transformations
end  # module Plan
end  # module RCC
