#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/util/expression_forms/expression_form.rb"

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
         return BranchPoint.new( @branches.collect{|branch| branch.is_an?(ExpressionForm) ? branch.paths : branch} )
      end
      
      
   end # BranchPoint
   


end  # module ExpressionForms
end  # module Util
end  # module RCC
