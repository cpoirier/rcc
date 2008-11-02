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
require "#{RCC_LIBDIR}/plan/transformations/transform.rb"

module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class AssignmentTransform

   class AssignmentTransform < Transform
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( lhs_selector, rhs_selector )
         super( lhs_selector, rhs_selector )
      end
      
      
      #
      # apply()
      #  - performs the transform
      
      def apply( node )
         @lhs_selector.assign( node, @rhs_selector.apply(node) )
      end
      
      
   end # AssignmentTransform
   


end  # module Transformations
end  # module Plan
end  # module RCC
