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
