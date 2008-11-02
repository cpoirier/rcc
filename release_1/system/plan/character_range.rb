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
require "#{RCC_LIBDIR}/util/sparse_range.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class CharacterRange
 #  - the Plan's idea of a CharacterRange; it's analogous to the Model CharacterRange
 #  - interface compatible with Symbol, for the purpose of State generation

   class CharacterRange < Util::SparseRange
      
      def self.from_model( character_range )
         return new( *character_range.instance_eval{@ranges} )
      end
      
      attr_reader :name
      
      def initialize( *ranges )
         super( *ranges )
         @name = Scanner::Artifacts::Name.new( self )
      end
      
      def lexical?()
         return true
      end
      
      def syntactic?()
         return false
      end
      
      def symbolic?()
         return false
      end

      def signature()
         return to_s()         
      end
      
      def refers_to_character?()        ; return true  ; end
      def refers_to_token?()            ; return false ; end
      def refers_to_producible_token?() ; return false ; end
      def refers_to_production?()       ; return false ; end
      def refers_to_group?()            ; return false ; end
      def refers_to_discarder?()        ; return false ; end

      def token_names()
         return []
      end

      def gateways()
         return []
      end

      def description( elide_grammar = nil )
         return @name.description
      end
      
      alias full_description description
      
   end # CharacterRange
   


   


end  # module Plan
end  # module RCC
