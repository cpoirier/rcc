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
 # class Subtree
 #  - a base class for nodes that contain other nodes

   class Subtree < Node
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :token_count               # The number of Tokens in this and all sub CSNs
      attr_reader :original_error_position   # The stream position at which the last original (non-cascade) error occurred
      
      def initialize( type, component_nodes )
         super( type )
         @token_count = component_nodes.inject(0) {|sum, node| node.token_count }

         @tainted     = false
         @recoverable = false
         component_nodes.each do |node|
            @tainted = true if node.tainted?
            
            if node.corrected? then
               @corrections = [] if @corrections.nil?
               @corrections.concat( node.corrections )
            end
         end
         
         @original_error_position = 0
         @original_error_position = @corrections[-1].original_error_position if defined?(@corrections) and !@corrections.empty?
      end
      
      def description()
         return "#{@type}"
      end
      
      def follow_position()
         return last_token().follow_position()
      end
      
      def first_token()
         bug( "you must override first_token()" )
      end

      def last_token()
         bug( "you must override last_token()" )
      end
      
      def line_number()
         return first_token.line_number()
      end
      
      def column_number()
         return first_token.column_number()
      end
      
      def start_position()
         return first_token.start_position()
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # tainted?
      #  - returns true if this CSN carries Correction taint
      
      def tainted?()
         return @tainted
      end
      
      
      #
      # untaint()
      #  - clears the taint from this Node (any Correction is still linked)
      
      def untaint()
         @tainted = false
      end
      
      
      #
      # recoverable?
      #  - returns true if this Node can anchor 
      
      attr_writer :recoverable
      
      def recoverable?()
         return @recoverable
      end
      
   end # Node
   


end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC

