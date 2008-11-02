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
 # class TransitiveClosure
 #  - a selector that repeatedly applies another selector to a set of nodes, merging in the results, until all results are 
 #    found

   class TransitiveClosure < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :selector
      
      def initialize( selector )
         super( false )
         @selector = selector
      end
      
      
      #
      # apply()
      #  - transitive closure always results in plural results
      #  - we assume most trees are left-associative, and so reverse the results order
      
      def apply( nodes )
         nodes      = nodes.to_a
         results    = nodes
         difference = nodes
         until difference.empty?
            step_results = @selector.apply( difference )
            difference   = step_results - results
            results.concat( difference )
         end
         
         return results.reverse
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << "{" << @selector << "}"
      end
      
      
   end # TransitiveClosure
   


end  # module Transformations
end  # module Plan
end  # module RCC
