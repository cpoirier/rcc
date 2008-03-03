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
         
         #
         # First, compile the element to its paths.  We will end up with a BranchPoint.
         
         element_paths = nil
         if @element.is_an?(ExpressionForm) then
            element = @element.paths
         else
            element = BranchPoint.new( Sequence.new(@element) )
         end
         
         #
         # Next, produce a BranchPoint with a Sequence for each count we are doing.
         
         run = Sequence.new()
         minimum.times do
            run << element
         end
         
         result = BranchPoint.new( run )
         (maximum - minimum).times do
            run = Sequence.new( run, element )
            result << run
         end
         
         
         #
         # Finally, get the paths of the produced Sequence.
         
         return result.paths
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
         yield( @element )
      end
      
      
      #
      # element_count()
      #  - returns the number of times your block will be called during each_elements
      
      def element_count()
         return 1
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         if @minimum == 0 and @maximum == 1 then
            stream << "optional: "
         else
            stream << "#{@minimum}-#{@maximum.nil? ? "*" : @maximum} times: " 
         end
         
         stream.indent do 
            @element.display(stream)
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

