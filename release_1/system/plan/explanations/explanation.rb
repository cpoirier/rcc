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
module Explanations

 
 #============================================================================================================================
 # class Explanation
 #  - base class for things that explain why actions where produced the way they were

   class Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
      end
      
      def to_s()
         return self.class.name
      end
      
      def display( stream = $stdout )
         stream << self.to_s << "\n"
      end
      
      
      
   end # Explanation
   



end  # module Explanations
end  # module Plan
end  # module RCC



require "#{RCC_LIBDIR}/plan/explanations/backtracking_activated.rb"
require "#{RCC_LIBDIR}/plan/explanations/initial_options.rb"
require "#{RCC_LIBDIR}/plan/explanations/items_do_not_meet_threshold.rb"
require "#{RCC_LIBDIR}/plan/explanations/only_one_choice.rb"
require "#{RCC_LIBDIR}/plan/explanations/left_assoc_reduce_eliminates_shift.rb"
require "#{RCC_LIBDIR}/plan/explanations/right_assoc_reduce_eliminated.rb"
require "#{RCC_LIBDIR}/plan/explanations/left_assoc_reduce_eliminated.rb"

