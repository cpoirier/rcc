#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"
require "#{RCC_LIBDIR}/plan/transformations/selector.rb"

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
      # unset()
      
      def unset( search_nodes )
         return super unless target?
         
         update( search_nodes ) do |node|
            node.undefine_slot( @slot_name )
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
