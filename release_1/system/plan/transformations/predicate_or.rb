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
require "#{RCC_LIBDIR}/util/expression_forms/sequence.rb"


module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class PredicateOr
 #  - a specialized BranchPoint for holding ORd predicates

   class PredicateOr < Util::ExpressionForms::BranchPoint
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      
      #
      # apply()
      #  - for PredicateOr, we take the union of all produced node(s)
      
      def apply( nodes )
         Predicate.apply(nodes) do |nodes|
            results = []
            self.each_element do |element|
               results |= element.apply(nodes)
            end
            results
         end
      end
      
      
      #
      # assign()
      
      def assign( search_nodes, result_nodes )
         return self.apply( search_nodes )
      end
      
      
      #
      # append()
      
      def append( search_nodes, results_nodes )
         return self.apply( search_nodes )
      end
      
            
      #
      # display()
      
      def display( stream = $stdout )
         show_separator = false
         self.branches.each do |element|
            stream << "|" if show_separator
            stream << "(" << element << ")"
            
            show_separator = true
         end
      end
      
      
   end # PredicateOr
   


end  # module Transformations
end  # module Plan
end  # module RCC


