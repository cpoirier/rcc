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
 # class SelfSelector
 #  - a selector that returns its input verbatim

   class SelfSelector < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( target )
         super( target )
      end
      
      
      #
      # apply()
      #  - applies this selector to a node set, returning the resulting node(s)
      
      def apply( node )
         return node
      end
      
      
      #
      # assign()
      #  - for self assignment, we need help; because nodes don't know their parent, we
      #    can't actually affect the change directly; instead, we set the ASN usurper, and
      #    leave ASN.commit() to do the patch up
      
      def assign( search_nodes, result_nodes )
         return super unless target?
         
         update(search_nodes) do |node|
            node.usurper = result_nodes
         end
      end
      
      
      #
      # append()
      
      def assign( search_nodes, result_nodes )
         return super unless target?
         nyi( nil, "what does self-append even mean?" )
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << "."
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
