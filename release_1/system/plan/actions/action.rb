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
module Actions

 
 #============================================================================================================================
 # class Action
 #  - base class for Parser actions 

   class Action
      
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
      
      def explanations()
         return has_explanations? ? @explanations : nil
      end

      def explanations=( explanations )
         @explanations = explanations
      end
      
      def has_explanations?()
         return (defined?(@explanations) and @explanations.set?)
      end
      
   end # Action
   


end  # module Actions
end  # module Plan
end  # module RCC




require "#{RCC_LIBDIR}/plan/actions/shift.rb"
require "#{RCC_LIBDIR}/plan/actions/reduce.rb"
require "#{RCC_LIBDIR}/plan/actions/discard.rb"
require "#{RCC_LIBDIR}/plan/actions/accept.rb"
require "#{RCC_LIBDIR}/plan/actions/attempt.rb"
require "#{RCC_LIBDIR}/plan/actions/read.rb"
require "#{RCC_LIBDIR}/plan/actions/continue.rb"
require "#{RCC_LIBDIR}/plan/actions/group.rb"
require "#{RCC_LIBDIR}/plan/actions/tokenize.rb"
