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

module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class Selector
 #  - a base class for things that select nodes from an ASN as part of a transformation

   class Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_accessor :target_predicate
      
      def initialize( target )
         @target = target
      end
      
      def target?()
         return @target
      end
      
      def has_target_predicate?()
         return (defined?(@target_predicate) and @target_predicate.exists?)
      end
      
      
      #
      # apply()
      #  - applies this selector to a node set, returning the resulting node(s)
      #  - always returns a list in a plural context 
      
      def apply( node )
         bug( "you must override Selector.apply()" )
      end
      
      
      #
      # assign()
      #  - most selectors can't be assigned to, but can form the path to the target
      
      def assign( search_nodes, result_nodes )
         return apply(search_nodes)
      end
      
      
      #
      # append()
      #  - most selectors can't be append to, but can form the path to the target
      
      def append( search_nodes, result_nodes )
         return apply(search_nodes)
      end
      
      
      #
      # unset()
      #  - most selectors can't be unset, but can form the path to the target
      
      def unset( search_nodes )
         return apply(search_nodes)
      end

      
      #
      # targets()
      #  - used to collect targets for LHS selectors
      
      def targets()
         if @target then
            return [self]
         else
            return []
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         if target? then
            stream << " (target)"
            stream << " if " << @target_predicate if has_target_predicate?
         end
      end
      
      
   end # Selector
   


end  # module Transformations
end  # module Plan
end  # module RCC


require "#{RCC_LIBDIR}/plan/transformations/selector_sequence.rb"
require "#{RCC_LIBDIR}/plan/transformations/selector_branch.rb"

require "#{RCC_LIBDIR}/plan/transformations/self_selector.rb"
require "#{RCC_LIBDIR}/plan/transformations/slot_selector.rb"
require "#{RCC_LIBDIR}/plan/transformations/reverse_selector.rb"
require "#{RCC_LIBDIR}/plan/transformations/transitive_closure.rb"
require "#{RCC_LIBDIR}/plan/transformations/predicate.rb"
