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

 
 #============================================================================================================================
 # class SparseArray
 #  - an Array-like class that can assign elements to a range of indices
 #  - will behave appropriately if sub-ranges of existing ranges are then overridden
 
   class SparseArray
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( pairs = {} )
         @ranges = []      # an ordered list of the ranges in the array
         @data   = []      # the data for the corresponding range in @ranges
         
         pairs.each do |range, value|
            self[range] = value
         end
      end
      
      def empty?()
         return @ranges.empty?
      end
      
      def each()
         @ranges.length.times do |i|
            yield( @ranges[i], @data[i] )
         end
      end
      
      
      #
      # []
      #  - if index is a number, return the element at the index
      #  - if index is a range, return all elements covered by that range (as a list)
      
      def []( index )
         result = nil
         
         if index.is_a?(SparseRange) then
            result = []
            index.each_range do |range|
               result.concat( self[range] )
            end
            result.uniq!
         else
            first_index = index.is_a?(Range) ? index.first : index
            range_index = find_range_index( first_index )
            if @ranges[range_index] === first_index then
               if index.is_a?(Range) then
                  result = []
                  until (range_index == @ranges.length or @ranges[range_index].first > index.last)
                     result << @data[range_index] 
                     range_index += 1
                  end
               else
                  result = @data[range_index]
               end
            end
         end
         
         return result
      end
      
      
      #
      # []=
      #  - if index is a number, sets the value at that index
      #  - if index is a range, sets the value at all those indices
      
      def []=( index, value )
         if index.is_a?(SparseRange) then
            index.each_range do |range|
               self[range] = value
            end
            
            return
         end
         
         range = index.is_a?(Range) ? index : index..index
         start_index = find_range_index( range.first )
         end_index   = find_range_index( range.last  )

         
         #
         # If start_index >= @ranges.length, everything in the range is before the new data.  
         # We append the data.
         
         if start_index >= @ranges.length then
            @ranges << range
            @data   << value
            
         #
         # If the found @ranges[start_index] > range.last, we can just insert the new data before it.
         
         elsif @ranges[start_index].first > range.last then
            @ranges[start_index, 0] = range
            @data[start_index, 0]   = value
            
         #
         # If the new range completely overlaps existing data, we can replace it.
         
         elsif @ranges[start_index].first >= range.first and (end_index == @ranges.length or @ranges[end_index].last <= range.last) then
            @ranges[start_index..end_index] = range
            @data[start_index..end_index]   = value
            
         #
         # If the new range completely overlaps the start of an existing range . . . 
         
         elsif @ranges[start_index].first >= range.first then
            
            #
            # If the end_index range is beyond the new range, replace from the start_index up to that point.
            
            if end_index == @ranges.length or @ranges[end_index].first > range.last then
               @ranges[start_index..(end_index-1)] = range
               @data[start_index..(end_index-1)]   = value
               
            #
            # Otherwise, split the end_index range and data, and replace everything else.
            
            else
               @ranges[start_index..end_index] = [range, (range.last+1)..@ranges[end_index].last]
               @data[start_index..end_index]   = [value, @data[end_index]                       ]
            end
            
         #
         # If the new range completely overlaps the end of an existing range, split the start_index range
         # and data, and replace everything else (an earlier test has handled the completely overlapped 
         # start_index range case).
         
         elsif end_index == @ranges.length or @ranges[end_index].last <= range.last then
            @ranges[start_index..end_index] = [@ranges[start_index].first..(range.first-1), range]
            @data[start_index..end_index]   = [@data[start_index]                         , value]
            
            
         #
         # Otherwise, we are splitting both the start_index range and the end_index range.
            
         else
            @ranges[start_index..end_index] = [@ranges[start_index].first..(range.first-1), range, (range.last+1)..@ranges[end_index].last]
            @data[start_index..end_index]   = [@data[start_index]                         , value, @data[end_index]                       ]
         end
      end
      
      
      #
      # separate_over()
      #  - given a range, separates existing elements as necessary to ensure the specified range can be 
      #    uniquely addressed
      #  - can optional call dup() on values during separation, either :none, :inside, or :outside
      
      def separate_over( index, dup_policy = :none )
         range = index.is_a?(Range) ? index : index..index
         start_index = find_range_index( range.first )
         end_index   = find_range_index( range.last  )
         
         covered_ranges = []


         #
         # If the range is entirely after, before, or between the current ranges, everything is 
         # already separate, and we have nothing more to do.
         
         if start_index >= @ranges.length or (@ranges[start_index].first > range.last) then
            covered_ranges << range
            
            
         #
         # Otherwise, we are splitting existing ranges.
         
         else
            
            middle_first = range.first
            middle_last  = range.last
            append_range = nil
            
            #
            #    |-------|   range
            # ------|        found
            # =====================
            # --||--|        result
            
            if @ranges[start_index].first < range.first and @ranges[start_index].last >= range.first then
               p "a"
               p @ranges[start_index]
               p range
               
               case dup_policy
               when :outside
                  self[@ranges[start_index].first..(range.first-1)] = @data[start_index].dup
                  start_index += 1
                  end_index   += 1
               when :inside
                  self[range.first..@ranges[start_index].last] = @data[start_index].dup
                  start_index += 1
                  end_index   += 1
               end
               
               covered_ranges << (range.first..(@ranges[start_index].last))
               middle_first = @ranges[start_index].last + 1
               start_index += 1
            end
            
            #
            #
            #    |-------|    range
            #         |------ found
            # ======================
            #         |--||-- result
            
            if end_index < @ranges.length then
               p "b"
               case dup_policy
               when :outside
                  self[(range.last + 1)..@ranges[end_index].last] = @data[end_index].dup
               when :inside
                  self[@ranges[end_index].first..range.last] = @data[end_index].dup
               end
               
               append_range = ((@ranges[end_index].first)..range.last)
               middle_last  = @ranges[end_index].first - 1
               end_index -= 1
            else
               end_index = @ranges.length - 1
            end
            
            #
            #  |---------------------|   range
            #     |--|    |-------|      found
            # =================================
            #  |-||--||--||-------||-|   result
            #
            # The stuff in between doesn't get duped, but we do have to fill in any gaps not directly 
            # covered by the existing ranges.
            
            (start_index..end_index).each do |index|
               p "c"
               if middle_first < @ranges[index].first then
                  covered_ranges << (middle_first..(@ranges[index].first - 1))
                  middle_first = @ranges[index].last + 1
               end
               
               covered_ranges << @ranges[index]
            end
            
            if middle_first <= middle_last then
               covered_ranges << (middle_first..middle_last)
            end
            
            covered_ranges << append_range unless append_range.nil?
         end
         
         return covered_ranges
      end
      




      def ==( rhs )
         local_ranges = @ranges
         local_data   = @data
         
         rhs.instance_eval do
            return (local_ranges == @ranges && local_data == @data)
         end
      end


      def display( stream = $stdout )
         @ranges.length.times do |i|
            stream << @ranges[i].to_s << " = " << @data[i].to_s
            stream.end_line
         end
      end
      
      
      def to_s()
         pieces = []
         @ranges.length.times do |i|
            pieces << "#{@ranges[i]} => #{@data[i]}"
         end
         
         return pieces.join(", ")
      end
      
      
      def dup()
         pairs = {}
         @ranges.length.times do |i|
            pairs[@ranges[i].dup] = @data[i].dup
         end
         
         return self.class.new( pairs )
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Operations Support
    #---------------------------------------------------------------------------------------------------------------------
          
    protected
    
      #
      # find_range_index()
      #  - returns the lowest @range index corresponding to the specified index
      #  - if there isn't a direct match, returns the index of the first range above it
      
      def find_range_index( index )
         
         #
         # Binary search through @ranges for one that contains index.  If we don't
         # find one, we fall back to the next range of greater first value.
         
         start_index      = 0
         end_index        = @ranges.length - 1
         fallback_index   = @ranges.length
         previous_attempt = nil
         
         while end_index >= 0 and start_index < @ranges.length and end_index >= start_index
            current_index = ((end_index - start_index) / 2).floor + start_index
            current_index += 1 if current_index == previous_attempt
            
            # puts "start_index = #{start_index}; end_index = #{end_index}; current_index = #{current_index}; limit = #{@ranges.length}"
            
            if @ranges[current_index].first > index then
               fallback_index = current_index
               end_index      = current_index - 1
            elsif @ranges[current_index].last < index then
               start_index = current_index + 1
            else
               assert( @ranges[current_index] === index, "wtf?" )
               break
            end
            
            previous_attempt = current_index
            current_index    = nil
         end
         
         return current_index.nil? ? fallback_index : current_index
      end
      
      
   end # SparseArray
   


end  # module Util
end  # module RCC




if $0 == __FILE__ then
   C = RCC::Util::SparseArray
   array = C.new( 5..10 => "a", 28..30 => "b" )

   test = C.new( 5..10 => "a", 28..30 => "b" )
   puts (array == test ? "PASS" : "FAIL") + ": #{array}   ==   #{test}"
   puts ""
   
   test = C.new( 5..10 => "a", 28..29 => "b" )
   puts (array == test ? "FAIL" : "PASS") + ": #{array}   !=   #{test}"
   puts ""
   
   puts "START: #{array}"
   puts ""
   
   [ 
      [13..15 , "c", C.new( 5..10 => "a", 13..15 => "c", 28..30 => "b"                                                                                       )],
      [19..23 , "d", C.new( 5..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "b"                                                                        )],
      [ 1..3  , "f", C.new( 1..3 => "f", 5..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "b"                                                           )],
      [ 2..5  , "g", C.new( 1..1 => "f", 2..5 => "g", 6..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "b"                                              )],
      [28..30 , "h", C.new( 1..1 => "f", 2..5 => "g", 6..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "h"                                              )],
      [40..49 , "i", C.new( 1..1 => "f", 2..5 => "g", 6..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "h", 40..49 => "i"                               )],
      [42..47 , "j", C.new( 1..1 => "f", 2..5 => "g", 6..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "h", 40..41 => "i", 42..47 => "j", 48..49 => "i" )],
      [41..48 , "k", C.new( 1..1 => "f", 2..5 => "g", 6..10 => "a", 13..15 => "c", 19..23 => "d", 28..30 => "h", 40..40 => "i", 41..48 => "k", 49..49 => "i" )],
      [ 4..22 , "l", C.new( 1..1 => "f", 2..3 => "g", 4..22 => "l", 23..23 => "d", 28..30 => "h", 40..40 => "i", 41..48 => "k", 49..49 => "i"                )],
      [24..27 , "m", C.new( 1..1 => "f", 2..3 => "g", 4..22 => "l", 23..23 => "d", 24..27 => "m", 28..30 => "h", 40..40 => "i", 41..48 => "k", 49..49 => "i" )],
      [18..49 , "n", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n"                                                                            )],
      [72..79 , "o", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n", 72..79 => "o"                                                             )],
      [92..99 , "p", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n", 72..79 => "o", 92..99 => "p"                                              )],
      [71..81 , "q", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n", 71..81 => "q", 92..99 => "p"                                              )],
      [71..93 , "r", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n", 71..93 => "r", 94..99 => "p"                                              )],
      [81..93 , "s", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n", 71..80 => "r", 81..93 => "s", 94..99 => "p"                               )],
      [75..86 , "t", C.new( 1..1 => "f", 2..3 => "g", 4..17 => "l", 18..49 => "n", 71..74 => "r", 75..86 => "t", 87..93 => "s", 94..99 => "p"                )],
      [ 0..100, "u", C.new( 0..100 => "u"                                                                                                                    )],
      
      
   ].each do |test|
      range, value, result = *test
      
      puts "array[#{range}] = #{value}:"
      array[range] = value
      
      if array == result then
         puts "PASS: #{array}"
      else
         puts "FAIL: #{array}"
         puts "EXP : #{result}"
      end
      
      puts ""
   end
   
end

