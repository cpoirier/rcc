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

 
 #============================================================================================================================
 # class SparseRange
 #  - a Range-like class than can handle gaps in the range

   class SparseRange
      
      def self.deformed( *ranges )
         with_context_variable( :no_cleanup, true ) do
            return new( *ranges )
         end
      end
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( *ranges )
         @ranges = []
         ranges.each do |range|
            add( range )
         end
      end
      
      
      def length()
         length = 0
         @ranges.each do |range|
            length += range.last - range.first + 1
         end
         return length
      end
      
      def first()
         return nil if @ranges.empty?
         return @ranges[0].first
      end
      
      
      def last()
         return nil if @ranges.empty?
         return @ranges[-1].last
      end
      
      
      def to_s()
         "[" + @ranges.collect{|r| r.to_s}.join(" ") + "]"
      end
      
      
      def ==( rhs )
         local = @ranges
         rhs.instance_eval do
            return local == @ranges
         end
      end
      
      
      def +( rhs )
         result = self.class.new( *@ranges )
         result.add( rhs )
         return result
      end
      
      
      def -( rhs )
         result = self.class.new( *@ranges )
         result.subtract( rhs )
         return result
      end
      
      
      def &( rhs )
         results = []
         set1 = [] + @ranges.dup
         set2 = [] + rhs.instance_eval{@ranges}
         
         range1 = set1.shift
         range2 = set2.shift
         while range1.exists? and range2.exists?
            if range1.first <= range2.first and range1.last >= range2.last then
               results << range2
               range2 = set2.shift
            elsif range2.first <= range1.first and range2.last >= range1.last then
               results << range1
               range1 = set1.shift
            else
               if range1 === range2.first then
                  results << (range2.first..range1.last)
                  range1 = set1.shift
               elsif range2 === range1.first then
                  results << (range1.first..range2.last)
                  range2 = set2.shift
               else
                  if range1.first < range2.first then
                     range1 = set1.shift
                  else
                     range2 = set2.shift
                  end
               end
            end
         end
            
         return self.class.new( *results )
      end
      
      
      def ^( rhs )
         with_context_variable( :no_cleanup, true ) do
            overlap = (self & rhs)
            result = nil
            ranges = nil
            
            if overlap.empty? then
               ranges = (@ranges + rhs.instance_eval{@ranges}).sort{|a, b| a.first <=> b.first }
            else
               ranges = ((self - overlap).instance_eval{@ranges} + overlap.instance_eval{@ranges} + (rhs - overlap).instance_eval{@ranges}).sort{|a, b| a.first <=> b.first }
            end

            return self.class.new( *ranges )
         end
      end
      
      
      #
      # each()
      #  - calls your block once for each number in the range
       
      def each( )
         @ranges.each do |range|
            range.each do |number|
               yield( number )
            end
         end
      end
      
      def each_range()
         @ranges.each do |range|
            yield( range )
         end
      end
      
      
      def member?( number )     
         case number
            when SparseRange
               number.each_range do |range|
                  return false unless member?(range)
               end
               return true
            when Range
               @ranges.each do |range|
                  return true if (range.first <= number.first and range.last >= number.last)
               end
            else
               @ranges.each do |range|
                  return true if range.member?(number)
               end
         end
         
         return false
      end

      def overlaps?( other )
         case other
         when SparseRange
            other.each_range do |piece|
               return true if overlaps?(piece)
            end
         when Range
            @ranges.each do |range|
               return true if range.member?(other.first)
               return true if range.member?(other.last)
               return true if (other.first < range.first and other.last > range.last)
            end
         end
         
         return false
      end

      def empty?
         return @ranges.empty?
      end
      
      
      def replace( sparse_range )
         data = nil
         sparse_range.instance_eval do
            data = @ranges.dup
         end
         @ranges = data
      end
      
      
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # add()

      def add( delta )
         case delta
            when Numeric
               add( delta..delta )
               
            when Range
               if @ranges.empty? then
                  @ranges << delta
               elsif @ranges[0].begin > delta.end then
                  @ranges.unshift delta
                  cleanup(0)
               elsif @ranges[-1].end < delta.begin
                  @ranges.push delta
                  cleanup( @ranges.length - 2 )
               else
                  @ranges.length.times do |index|
                     existing_range = @ranges[index]
                     if existing_range.begin <= delta.begin and (existing_range.end + 1) >= delta.begin then
                        if context_variable(:no_cleanup) then
                           @ranges[index+1, 0] = delta
                        else                        
                           extend_range(index, delta.end)
                        end
                        break
                     elsif existing_range.begin > delta.end then
                        @ranges[index, 0] = delta
                        cleanup( index )
                        break
                     end
                  end
               end
               
            when SparseRange
               delta.instance_eval{@ranges}.each do |range|
                  add( range )
               end
            
            else
               bug( "unsupported RHS type [#{delta.class.name}]" )
         end
      end


      #
      # subtract()
      
      def subtract( delta )
         case delta
            when Numeric
               subtract( delta..delta )
         
            when Range
               
               #
               # First, remove any ranges that are wholly covered.
         
               @ranges.reject! do |range|
                  range.begin >= delta.begin and range.end <= delta.end
               end
         
               #
               # Next, split any range we punch a whole through (there will be only one).
         
               @ranges.length.times do |index|
                  range = @ranges[index]
                  if range.begin < delta.begin and range.end > delta.end then
                     @ranges[index, 1] = [range.begin..(delta.begin-1), (delta.end + 1)..range.end]
                     break
                  end
               end
         
               #
               # Finally, adjust any ranges that are partially covered.
         
               @ranges.length.times do |index|
                  range = @ranges[index]
                  if range === delta.begin and range.begin != delta.begin then
                     @ranges[index] = range.begin..(delta.begin - 1)
                  elsif range === delta.end then
                     @ranges[index] = (delta.end + 1)..range.end
                  end
               end

            when SparseRange
               delta.instance_eval{@ranges}.each do |range|
                  subtract( range )
               end

            else
               bug( "unsupported RHS type [#{rhs.class.name}]" )
         end
      end




      

    #---------------------------------------------------------------------------------------------------------------------
    # Operations Support
    #---------------------------------------------------------------------------------------------------------------------
          
    protected
      
      #
      # extend_range()

      def extend_range( index, new_end_point )
         @ranges[index] = (@ranges[index].begin)..max(new_end_point, @ranges[index].end)
         cleanup( index )
      end
      
      
      #
      # cleanup()
      #  - after a change is made to the @ranges array, goes through and ensures any overlapping 
      #    or adjacent ranges are merged
      
      def cleanup( from_index )
         return if context_variable(:no_cleanup)
         next_index = from_index + 1
         while @ranges.length > (next_index)
            if @ranges[from_index].end + 1 >= @ranges[next_index].begin then
               @ranges[from_index] = (@ranges[from_index].begin)..(max(@ranges[from_index].end, @ranges[next_index].end))
               @ranges.delete_at( next_index )
            else
               break
            end
         end
      end
      
   end # SparseRange
   


end  # module Util
end  # module RCC




if $0 == __FILE__ then
   C = RCC::Util::SparseRange
   range = C.new( 5..10, 28..30 )
   
   test = C.new(5..10, 28..30)
   puts (range == test ? "PASS" : "FAIL") + ": #{range}   ==   #{test}"
   puts ""
   
   test = C.new(5..10, 28..29)
   puts (range == test ? "FAIL" : "PASS") + ": #{range}   !=   #{test}"
   puts ""

   [ 
      [true , 13..15 , C.new( 5..10, 13..15, 28..30                         )], 
      [true , 19..23 , C.new( 5..10, 13..15, 19..23, 28..30                 )], 
      [true ,  1..3  , C.new( 1..3, 5..10, 13..15, 19..23, 28..30           )], 
      [true ,  2..5  , C.new( 1..10, 13..15, 19..23, 28..30                 )], 
      [false, 26..40 , C.new( 1..10, 13..15, 19..23                         )],
      [true , 28..30 , C.new( 1..10, 13..15, 19..23, 28..30                 )],
      [false, 28..30 , C.new( 1..10, 13..15, 19..23                         )],
      [true , 28..30 , C.new( 1..10, 13..15, 19..23, 28..30                 )],
      [true , 40..49 , C.new( 1..10, 13..15, 19..23, 28..30, 40..49         )], 
      [false, 42..47 , C.new( 1..10, 13..15, 19..23, 28..30, 40..41, 48..49 )],
      [false, 41..48 , C.new( 1..10, 13..15, 19..23, 28..30, 40..40, 49..49 )],
      [true ,  4..22 , C.new( 1..23, 28..30, 40..40, 49..49                 )], 
      [true , 24..27 , C.new( 1..30, 40..40, 49..49                         )], 
      [false, 18..49 , C.new( 1..17                                         )],
      [true ,  1..100, C.new( 1..100                                        )],
       
      
   ].each do |test|
      addition, delta, result = *test
      if addition then
         puts "#{range}   +   #{delta}   ="
         range = range + delta
         
      else
         puts "#{range}   -   #{delta}   ="
         range = range - delta
      end
      
      if range == result then
         puts "PASS: #{range}"
      else
         puts "FAIL: #{range}"
         puts "EXP : #{result}"
      end
      puts ""
   end
   
   
   range = C.new(141..141)
   [
      [C.new( 80..90 )            , C.deformed(80..90, 141..141                                                                          )],
      [C.new( 5..10, 28..30 )     , C.deformed(5..10, 28..30, 80..90, 141..141                                                           )],
      [C.new( 3..4, 8..9, 30..50 ), C.deformed(3..4, 5..7, 8..9, 10..10, 28..29, 30..30, 31..50, 80..90, 141..141                        )],
      [C.new( 10..83 )            , C.deformed(3..4, 5..7, 8..9, 10..10, 11..27, 28..29, 30..30, 31..50, 51..79, 80..83, 84..90, 141..141)],
      [C.new( 0..65536 )          , C.deformed(0..2, 3..4, 5..7, 8..9, 10..10, 11..27, 28..29, 30..30, 31..50, 51..79, 80..83, 84..90, 91..140, 141..141, 142..65536)]
      
   ].each do |test|
      mask, result = *test
      
      puts "#{range} ^ #{mask} = "
      range ^= mask
      
      if range == result then
         puts "PASS: #{range}"
      else
         puts "FAIL: #{range}"
         puts "EXP : #{result}"
         break
      end
      
      puts ""
   end
   
end
