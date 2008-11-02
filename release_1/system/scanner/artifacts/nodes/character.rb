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
require "#{RCC_LIBDIR}/scanner/artifacts/node.rb"

module RCC
module Scanner
module Artifacts
module Nodes
   

 
 #============================================================================================================================
 # class Character
 #  - a single Character read from a source file

   class Character < Node
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :token_count               # The number of Tokens in this and all sub CSNs
      attr_reader :original_error_position   # The stream position at which the last original (non-cascade) error occurred
      attr_reader :line_number
      attr_reader :column_number
      attr_reader :source
      attr_reader :position 
      
      alias start_position position
      
      def initialize( code, position, source ) 
         code = source[position] if code.nil?
         super( Name.new(code) )
         
         @line_number   = source.line_number(position)
         @column_number = source.column_number(position)
         @position      = position
         @source        = source
      end
      
      def character()
         return @type.name
      end
      
      def description()
         return @type.to_s
      end
      
      def follow_position()
         return @position + 1
      end
      
      def character?()
         return true
      end
            
      def first_token()
         return nil
      end

      def last_token()
         return nil
      end
      






    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      
   end # Node
   


end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC

