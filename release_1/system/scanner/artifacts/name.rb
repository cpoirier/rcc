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
module Scanner
module Artifacts
   

 
 #============================================================================================================================
 # class Name
 #  - a class for names used and produced by an RCC lexer/parser system
 #  - names can be literal or symbolic; if symbolic, a grammar name must be included

   class Name
      
      
      def self.end_of_file_type()
         return @@end_of_file_type         
      end
      
      def self.any_type()
         return @@any_type
      end
      
      
      def self.in_grammar( grammar_name )
         with_context_variables( :grammar_name => grammar_name ) { yield() }
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :grammar
      attr_reader   :name
      attr_reader   :signature
      attr_accessor :source_token
      
      def initialize( name, grammar = nil, source_token = nil )
         @grammar      = grammar
         @name         = name
         @source_token = source_token
         
         case name
         when nil
            @signature = "$"
         when true
            @signature = "*"
         when Util::SparseRange
            @signature = name.to_s
         when Numeric
            @signature = "[#{name}]"
         else
            @signature = grammar.nil? ? "\"#{@name.escape}\"" : "#{@grammar}.#{@name}"
         end
      end
      
      
      def description( context = nil )
         if @name.nil? then
            return "$"
         elsif @name == true then
            return "*"
         else
            context = context_variable(:grammar_name) if context.nil?
            if context and context == @grammar then
               return @name
            else
               return @signature
            end
         end
      end

      
      def pluralize()
         return @name.pluralize()
      end
      
      
      def eof?()
         return @name.nil?
      end
      
      def wildcard?()
         return @name == true
      end

      
      def literal?
         return (@grammar.nil? and !(@name == true))
      end
      
      
      def character?()
         return @name.is_a?(Numeric)
      end
      
      def character_range?()
         return @name.is_a?(Util::SparseRange)
      end
      

      
      def ==( rhs )
         if rhs.is_a?(String) then
            return (@name == rhs || @signature == rhs)
         elsif rhs.is_a?(Numeric) then
            return @signature == "[#{rhs}]"
         else
            return @signature == rhs.signature
         end
      end
      
      def <=>( rhs )
         self.signature() <=> rhs.signature()
      end
      
      def hash()
         return @signature.hash
      end

      def ===( rhs )
         if rhs.is_a?(String) then
            return (@name == rhs || @signature == rhs)
         elsif rhs.is_a?(Numeric) then
            case @name
            when Util::SparseRange
               return @name.member?(rhs) 
            when Numeric
               return @name == rhs
            else
               return false
            end
         else
            return @signature == rhs.signature
         end
      end
      
      alias eql? ==
      alias to_s description
      
      
      

      @@end_of_file_type = self.new( nil, nil )
      @@any_type         = self.new( true, nil )
      
   end # Node
   


end  # module Artifacts
end  # module Scanner
end  # module RCC

