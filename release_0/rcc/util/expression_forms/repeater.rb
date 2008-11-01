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
      
      def optional?()
         return @minimum == 0
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
            run.minimal = false
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


      #
      # times()
      #  - calls your block the appropriate number of times for our minimum and maximum
      #  - passes invocation number, and a flag indicating if this pass is required
      #  - returns true; you can break with a different value, if you have a problem

      def times()
         i = 0
         
         @minimum.times do |i|
            yield( i + 1, @element, true )
         end
         
         if @maximum.nil? then
            while true
               i += 1
               yield( i + 1, false )
            end
         elsif @maximum > @minimum
            @minimum.upto(@maximum-1) do |i|
               yield( i + 1, false )
            end
         end
         
         return true
      end
      
      # def times()
      #    required_completions = 0
      # 
      #    begin
      #       i = 0
      #       @minimum.times do |i|
      #          yield( i + 1, @element, true )
      #          required_completions += 1
      #       end
      #    
      #       if @maximum.nil? then
      #          while true
      #             i += 1
      #             yield( i + 1, false )
      #          end
      #       elsif @maximum > @minimum
      #          @minimum.upto(@maximum-1) do |i|
      #             yield( i + 1, false )
      #          end
      #       end
      #       
      #    #
      #    # I don't like doing this this way, but I can't seem to catch LocalJumpError, and we
      #    # need the result, so . . . .
      #    
      #    ensure
      #       return required_completions >= @minimum
      #    end
      #    
      # end
      
      
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

