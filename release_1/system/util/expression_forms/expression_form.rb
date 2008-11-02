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
module Util
module ExpressionForms

 
 #============================================================================================================================
 # class ExpressionForm
 #  - base class fo ExpressionForm elements

   class ExpressionForm
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
      end
      
      
      def optional?()
         nyi()
      end
      
      
      #
      # paths()
      #  - returns an BranchPoint of ExpressionForms indicating all possible paths through this ExpressionForm
      
      def paths()
         return BranchPoint.new(self)
      end
      
      
      #
      # +()
      #  - returns a Sequence containing this element and the one you supply
      
      def +( rhs )
         return Sequence.new( self, rhs )
      end
      
      
      #
      # elementize()
      #  - returns an ExpressionForm, always
      
      def elementize( element )
         return element.is_an?(ExpressionForm) ? element : Leaf.new(element)
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
      end
      
      
      #
      # element_count()
      #  - returns the number of times your block will be called during each_elements
      
      def element_count()
         return 0
      end
      
      
      #
      # []
      #  - returns the element at the specified index, or nil
      
      def []( index )
         return nil if index >= element_count()
         each_element() do |element|
            return element if index == 0
            index -= 1
         end
      end
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << self.class.name.split("::")[-1].downcase << ": "
         stream << "\n" if element_count() != 1
         
         stream.indent do
            self.each_element do |element|
               element.display( stream )
               stream.end_line()
            end
         end
         
         stream.end_line()
      end

      
   end # ExpressionForm




 #============================================================================================================================
 # class Element
 #  - an ExpressionForm that holds non-ExpressionForm data within an ExpressionForm
 
   class Element < ExpressionForm
      attr_reader :datum
      
      def initialize( datum )
         @datum = datum
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
         yield( @datum )
      end


      
   end
      

    


end  # module ExpressionForms
end  # module Util
end  # module RCC


require "#{RCC_LIBDIR}/util/expression_forms/branch_point.rb"
require "#{RCC_LIBDIR}/util/expression_forms/sequence.rb"
require "#{RCC_LIBDIR}/util/expression_forms/repeater.rb"