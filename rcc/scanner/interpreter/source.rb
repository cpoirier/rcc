#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Scanner
module Interpreter

 
 #============================================================================================================================
 # class Source
 #  - holds a source file in memory
 #  - provides a character-addressable array of lines interface to it

   class Source
       
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :descriptor    # Some object describing where our input comes from
      attr_reader :length        # Character length of the text
      
      def initialize( text, descriptor = nil )
         @descriptor = descriptor
         @length     = text.length
         @lines      = text.split(/^/)
         
         position = -1
         @eol_positions = []
         @lines.each do |line|
            position += line.length 
            @eol_positions << position 
         end
         
         @last_line_referenced = 0
      end
      
      
      #
      # line_index()
      #  - returns the line index of the specified position
      
      def line_index( position )
         return nil if position < 0 or position >= @length
         
         #
         # Give fast answers if the user is accessing positions sequentially.
         
         unless @last_line_referenced.nil?
            eol_before = @last_line_referenced == 0 ? -1 : @eol_positions[@last_line_referenced - 1]
            eol_for    = @eol_positions[@last_line_referenced]
            eol_after  = @last_line_referenced + 1 >= @eol_positions.length ? @length : @eol_positions[@last_line_referenced + 1]
            
            if position > eol_before and position <= eol_for then
               return @last_line_referenced
            elsif position > eol_for and position <= eol_after then
               @last_line_referenced += 1
               return @last_line_referenced
            end
         end
         
         
         #
         # If we are still here, do a binary search of the @eol_positions array and find the referenced line.
         
         first = 0
         last  = @lines.length - 1
         
         while last > first
            middle = ((last + first) / 2).ceil
            
            if position > @eol_positions[middle] then
               first = (first == middle ? first + 1 : middle)
            elsif position <= @eol_positions[middle]
               last  = (last == middle  ? last - 1 : middle)
            end
         end
         
         @last_line_referenced = first
         return @last_line_referenced
      end
      
      
      #
      # column_index()
      #  - returns column index for the specified position
      #  - you can pass in the line index, if you already know it, to save time
      
      def column_index( position, line_index = nil )
         line_index = line_index(position) if line_index.nil?
         return nil if line_index.nil?
         
         if line_index == 0 then
            return position 
         else
            return position - @eol_positions[line_index - 1] - 1
         end
      end
      
      
      #
      # line()
      #  - returns the line at the specified position
      
      def line( position, position_is_line_index = false )
         line_index = position_is_line_index ? position : line_index(position)
         
         return @lines[line_index]
      end
      
      
      #
      # line_from()
      #  - returns everything from the position to the end of that line
      
      def line_from( position, line_index = nil )
         line_index = line_index(position) if line_index.nil?
         return nil if line_index.nil? or line_index >= @lines.length
         return @lines[line_index].slice(column_index(position, line_index)..-1)
      end
            
      
      
   end # Source
   


end  # module Interpreter
end  # module Scanner
end  # module RCC
