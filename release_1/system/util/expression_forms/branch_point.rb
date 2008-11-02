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
require "#{RCC_LIBDIR}/util/expression_forms/expression_form.rb"

module RCC
module Util
module ExpressionForms

 
 #============================================================================================================================
 # class BranchPoint
 #  - an ExpressionForm that holds one or more branches -- distinct paths through the form

   class BranchPoint < ExpressionForm
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :branches
      
      def initialize( *branches )
         @branches = []
         
         branches.flatten.each do |branch|
            self << branch
         end
      end
      
      def optional?()
         each_element do |element|
            return true if element.optional?
         end
         
         return false
      end
      
      
      #
      # <<()
      #  - adds a branch to this BranchPoint
      #  - if you attempt to add a BranchPoint as branch, its branches will be rolled up into this one
       
      def <<( branch )
         case branch
            when BranchPoint
               @branches.concat( branch.branches )
            else
               @branches << branch
         end
      end
      
      
      #
      # def ==()
      
      def ==( rhs )
         return @branches == rhs.branches
      end
      
      
      #
      # *()
      #  - returns the cross-product of this and another ExpressionForm
      
      def *( rhs )
         result = BranchPoint.new()
         
         if rhs.is_a?(BranchPoint) then
            @branches.each do |lhs_branch|
               rhs.branches.each do |rhs_branch|
                  result << Sequence.new(lhs_branch, rhs_branch)
               end
            end
         else
            @branches.each do |lhs_branch|
               result << Sequence.new(lhs_branch, rhs_branch)
            end
         end
         
         return result
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
         @branches.each do |branch|
            yield( branch )
         end
      end
      
      
      #
      # element_count()
      #  - returns the number of times your block will be called during each_elements
      
      def element_count()
         return @branches.length
      end
      


      #
      # paths()
      #  - returns a single BranchPoint containing only flattened Sequences showing every possible
      #    path through this ExpressionForm
      
      def paths()
         return BranchPoint.new( @branches.collect{|branch| branch.is_an?(ExpressionForm) ? branch.paths : Sequence.new(branch)} )
      end
      
      
   end # BranchPoint
   


end  # module ExpressionForms
end  # module Util
end  # module RCC
