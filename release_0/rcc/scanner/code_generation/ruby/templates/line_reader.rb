#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================


# %$#@TEMPLATE@#$% INSERT MODULE HEADER HERE
 

 #============================================================================================================================
 # class LineReader
 #  - an reversible line reader for use by the Lexer
 #  - acts like a gets()-able file, but is fully reversable to any position, and always knows the line and column number
 #    of the next position to be read

   class LineReader
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :descriptor    # Some object describing where our input comes from
      attr_reader :position      # The index of the next character to be read
      
      def initialize( input, descriptor = nil )
         @input        = input
         @descriptor   = descriptor
         @text         = ""            # The full text read from the input so far
         @position     = 0             # The index into @text at which to read the next character (possibly >@text.length)
         @line_endings = []            # Positions at which \n occur, but only before the @position; IN REVERSE ORDER
         @line_number  = nil           # The line number of @position, if already known
      end
      
      
      #
      # line_number
      #  - returns the line number of the next character to be read
      
      def line_number()
         if @line_number.nil? then
            @line_number = 1
            @line_endings.each do |line_ending|
               if @position > line_ending
                  @line_number += 1
               else
                  break
               end
            end
         end
         
         return @line_number
      end
      
      
      #
      # column_number
      #  - returns the column number of the next character to be read
      #  - usually 1, unless you've seek()ed somewhere
      
      def column_number()
         if line_number() == 1 then
            return @position + 1
         else
            return @position - @line_endings[0]
         end
      end
      
      
      #
      # seek()
      #  - seeks to the specified position 
      
      def seek( position )
         @position = position 
         
         @line_number = nil
         @line_endings.shift while !@line_endings.empty? and @line_endings[0] >= @position
      end
      
      
      #
      # gets()
      #  - gets a line of input, starting from the current position
      #  - position is updated as a result, so check it first, if you care
      #  - returned string includes any newline
      
      def gets()
         until (@position < @text.length and !@text.index("\n", @position).nil?)
            if line = @input.gets() then
               @text << line
            else
               break
            end
         end
         
         line = nil

         if @position < @text.length then
            newline_position = @text.index( "\n", @position )
            if newline_position.nil? then
               line = @text.slice( @position..-1 )
               @position = @text.length
               @line_endings.unshift( @text.length )
            else
               line = @text.slice( @position..newline_position )
               @position = newline_position + 1
               @line_endings.unshift( newline_position )
            end
            
            @line_number += 1 unless @line_number.nil?
         end
         
         return line
      end
      
      
      
   end # LineReader
   

# %$#@TEMPLATE@#$% INSERT MODULE FOOTER HERE
