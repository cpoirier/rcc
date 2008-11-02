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
require "#{RCC_LIBDIR}/plan/symbol.rb"
require "#{RCC_LIBDIR}/plan/production.rb"
require "#{RCC_LIBDIR}/scanner/artifacts/name.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class TokenProduction
 #  - a single compiled lexical Form, ready for use in the Plan

   class TokenProduction < Production
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      def initialize( number, name, symbols, tokenizeable = false, master_plan = nil )
         super( number, name, symbols, master_plan )
         @tokenizeable = tokenizeable
      end

      def tokenizeable?()
         return @tokenizeable
      end
      
      #
      # occlude()
      #  - returns a version of this TokenProduction with the first CharacterRange occluded by the supplied range
      #  - has no effect if the first isn't a CharacterRange
      
      def occlude( range, master_plan = nil )
         return self if @symbols[0].symbolic?
         
         bug( "huh?" ) if master_plan.nil?
         
         remaining = @symbols[0] - range
         if remaining.empty? then
            return nil
         elsif remaining == @symbols[0] then
            return self            
         else
            return self.class.new( @number, @name, [remaining] + @symbols.slice(1..-1), @tokenizeable, master_plan.nil? ? @master_plan : master_plan )
         end
      end
      
      
   end # TokenProduction
   




end  # module Plan
end  # module RCC
