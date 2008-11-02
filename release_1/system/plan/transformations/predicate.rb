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
 # class Predicate
 #  - a base class for things that eliminate nodes from Selector results set

   class Predicate < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         super( false )
      end
      
      
      #
      # apply()
      
      def apply( nodes )
         bug( "you must override Predicate.apply(), probably using Predicate::apply()" )
      end
      
      def self.apply( nodes )
         scalar   = !nodes.is_an?(Array)
         matching = yield(nodes.to_a)
         
         if scalar then
            return (matching.empty? ? nil : nodes)
         else
            return matching
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         @selector.display( stream )
         if block_given? then
            stream << "[" 
            yield()
            stream << "]"
         end
      end
      
      
   end # Predicate
   


end  # module Transformations
end  # module Plan
end  # module RCC


require "#{RCC_LIBDIR}/plan/transformations/predicate_and.rb"
require "#{RCC_LIBDIR}/plan/transformations/predicate_or.rb"

require "#{RCC_LIBDIR}/plan/transformations/exists_predicate.rb"
require "#{RCC_LIBDIR}/plan/transformations/inverted_predicate.rb"
require "#{RCC_LIBDIR}/plan/transformations/type_predicate.rb"
require "#{RCC_LIBDIR}/plan/transformations/not_type_predicate.rb"
