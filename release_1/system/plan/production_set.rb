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
require "#{RCC_LIBDIR}/plan/sequence_set.rb"
require "#{RCC_LIBDIR}/plan/production.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class ProductionSet
 #  - holds a related (in whatever way) set of Productions and provides useful services thereupon

   class ProductionSet < SequenceSet
      

    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :productions
      
      def initialize( productions = [] )
         super( productions.collect{|production| production.symbols} )
         @productions = productions
      end

      def <<( production )
         super( production.symbols )
         @productions << production
      end
      
      
      
   end # ProductionSet
   


end  # module Plan
end  # module RCC
