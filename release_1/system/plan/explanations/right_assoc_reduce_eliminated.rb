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
require "#{RCC_LIBDIR}/plan/explanations/explanation.rb"

module RCC
module Plan
module Explanations

 
 #============================================================================================================================
 # class RightAssocReduceEliminated
 #  - explanation that indicates a shift action was chosen over a reduce action for associativity reasons

   class RightAssocReduceEliminated < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( shift, reduction )
         @shift     = shift
         @reduction = reduction
      end
      
      
      def to_s()
         return "Shift [ #{@shift.to_s}] eliminates Reduce [ #{@reduction.to_s}]; equal precedence, reduce is right-associative"
      end
      
      
   end # RightAssocReduceEliminated
   



end  # module Explanations
end  # module Plan
end  # module RCC


