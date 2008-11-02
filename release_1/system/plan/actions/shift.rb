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
 # class Shift
 #  - a Shift action for the ParserPlan

   class Shift < Action
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :to_state
      attr_reader :valid_productions
      
      def initialize( symbol_name, to_state, valid_productions, commit_point )
         @symbol_name         = symbol_name
         @to_state            = to_state
         @valid_productions   = valid_productions
         @commit_point        = commit_point
      end
      
      def local_commit?()
         return @commit_point == :local
      end
      
      def global_commit?()
         return @commit_point == :global
      end
      
      def commit?()
         return !@commit_point.nil?
      end
      
      def valid_production?( production )
         return @valid_productions.member?(production)
      end
      
      def to_s()
         valid_names = @valid_productions.collect{|p| p.name}.uniq
         producing   = ""
         if valid_names.length == 1 then
            producing = "; to produce #{valid_names[0]}"
         else
            producing = "; to produce one of #{valid_names.join(" ")}"
         end
         
         return "Shift #{@symbol_name.description}, then goto #{@to_state.number}#{producing}"
      end
      
   end # Shift
   


end  # module Actions
end  # module Plan
end  # module RCC
