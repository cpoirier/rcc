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
module Predicates

 
 #============================================================================================================================
 # class Predicate
 #  - base class for recovery option Predicates

   class Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( insert = true, replace = true )
         @insert  = insert
         @replace = replace
      end
      
      def insert?()
         return @insert
      end
      
      def replace?()
         return @replace
      end
      
      def to_s()
         return self.class.name
      end
      
      def display( stream = $stdout )
         stream << self.to_s << "\n"
      end
      

      
   end # Predicate
   


end  # module Predicates
end  # module Plan
end  # module RCC




 
require "#{RCC_LIBDIR}/plan/predicates/check_context.rb"
require "#{RCC_LIBDIR}/plan/predicates/check_error_type.rb"
require "#{RCC_LIBDIR}/plan/predicates/try_it.rb"
