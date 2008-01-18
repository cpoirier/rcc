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

module RCC
module Util
module ExpressionForms

 
 #============================================================================================================================
 # class Repeater
 #  - a container for an ExpressionForm that may be repeated 0 or more times

   class Repeater < ExpressionForm
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :element
      attr_reader :minimum
      attr_reader :maximum
      
      def initialize( element, minimum = 1, maximum = nil )
         assert( minimum.exists?, "you must specify a minimum repeat count" )
         assert( maximum.nil? || minimum <= maximum, "minimum repeat count must be less than maximum repeat count" )
         
         @element = element
         @minimum = minimum
         @maximum = maximum
      end
      
      
      #
      # paths()
      #  - returns an BranchPoint of Sequences indicating all possible paths through this ExpressionForm
      
      def paths()
         assert( @maximum.exists?, "you cannot obtain paths() for an infinite Repeater" )
         assert( @maximum <= 10, "if you really need to obtain paths() for a Repeater with greater than 10 elements, change this assertion" )
         
         run = Sequence.new() 
         minimum.times do
            run << element
         end
         
         result = BranchPoint.new( run )
         (maximum - minimum).times do
            run += element
            result << run
         end

         return result
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
         yield( @element )
      end
      
      
      #
      # display()
      
      def display( stream )
         s1 = stream.indent

         stream << "repeated #{@minimum}-#{@maximum.nil? ? "*" : @maximum} times:" << "\n"
         self.each_element do |element|
            if element.is_an?(ExpressionForm) then
               element.display( s1 )
            else
               s1 << element.to_s << "\n"
            end
         end
      end

      
      
   end # Repeater
   




 #============================================================================================================================
 # class Optional
 #  - a container for an ExpressionForm that may or may not be present

   class Optional < Repeater
      def initialize( element )
         super( element, 0, 1 )
      end
   end




end  # module ExpressionForms
end  # module Util
end  # module RCC

