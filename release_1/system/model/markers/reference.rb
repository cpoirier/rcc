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
require "#{RCC_LIBDIR}/model/model.rb"

module RCC
module Model
module Markers
    
 
 #============================================================================================================================
 # class Reference
 #  - represents a reference in a rule

   class Reference
      include Model::Elements::SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbol_name
      alias name symbol_name
      
      def initialize( symbol_name )
         type_check( symbol_name, Scanner::Artifacts::Name )
         @symbol_name = symbol_name
      end
      
      
      #
      # resolve()
      #  - returns the object this Reference refers to
      
      def resolve( against )
         return against.resolve(symbol_name)
      end
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info(stream) do 
            stream.puts "#{@symbol_name}"
         end
      end
      
      
      def hash()
         return @symbol_name.hash
      end
      
      def ==( rhs )
         return @symbol_name == rhs.symbol_name
      end
      
      alias eql? ==
      
      
   end # Reference
   


end  # module Markers
end  # module Model
end  # module RCC
