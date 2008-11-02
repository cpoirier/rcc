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


require "#{File.dirname(File.expand_path(__FILE__))}/node.rb" 



%%MODULE_HEADER%%
 

 #============================================================================================================================
 # class Token
 #  - a Lexer-produced Node that contains a String from the source, plus information about its type and source location

   class Token < Node

      attr_reader :text                 # The text of this Token
      attr_reader :line_number          # The line number within the source this token came from
      attr_reader :column_number        # The column on which this token starts (if known)
      attr_reader :source_descriptor    # Some string that describes the source of this token
      
      def initialize( text, type, position, line_number, column_number, source_descriptor, value = nil )
         super( type.nil? ? text : type, value )
         
         @position          = position
         @line_number       = line_number
         @column_number     = column_number
         @source_descriptor = source_descriptor
      end
      
   end # Token
 


   

%%MODULE_FOOTER%%
