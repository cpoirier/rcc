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
module Plan
module DFA

 
 #============================================================================================================================
 # class PointSet
 #  - a wrapper for one or more Point, providing a Point-like interface for convenience

   class PointSet
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :points

      def initialize( points = [] )
         @points = points
      end

      def <<( point )
         if point.is_a?(PointSet) then
            @points.concat(point.points)
         else
            @points << point
         end
      end

      def +( points )
         return PointSet.new( @points + points.to_a )
      end

      def to_a()
         return @points
      end

      def minimal()
         if @points.length > 1 then
            return self
         else
            return @points[0]
         end
      end

      def empty?()
         return @points.empty?
      end

      def make_edge( inputs, vector = nil )
         return PointSet.new( @points.collect{|p| p.make_edge(inputs, vector)} )
      end

      def make_cycle( inputs, vector = nil )
         return PointSet.new( @points.collect{|p| p.make_cycle(inputs, vector)} )
      end

      def make_exit( vector = nil )
         return PointSet.new( @points.collect{|p| p.make_exit(vector)}.compact )
      end

      def display( stream = $stdout )
         index = 0
         @points.each do |point|
            stream.puts "[#{index}]"
            stream.indent do
               point.display(stream)
               stream.end_line
               stream.puts
            end

            index += 1
         end
      end

      
   end # PointSet
   



end  # module DFA
end  # module Plan
end  # module RCC
