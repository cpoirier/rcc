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
require "#{RCC_LIBDIR}/plan/actions/action.rb"

module RCC
module Plan
module Actions

 
 #============================================================================================================================
 # class Attempt
 #  - a Action that allows a set of Actions to be attempted, in sequence, until one of them succeeds

   class Attempt < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
      
      attr_reader :actions
      attr_reader :attempt_span
      attr_reader :last_is_longest
      
      def initialize( actions, attempt_span, last_is_longest )
         @actions         = actions
         @attempt_span    = attempt_span
         @last_is_longest = last_is_longest
      end
      
      def to_s()
         return "Attempt:\n   " + @actions.collect{|action| action.to_s}.join("\n   ")
      end
      
   end # Attempt
   


end  # module Actions
end  # module Plan
end  # module RCC
