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
module Scanner
module Artifacts

 
 #============================================================================================================================
 # class Source
 #  - holds a source file in memory, reading it from the stream on demand 
 #  - provides a character-code-addressable interface to it

   class Source
      
      def self.open( descriptor, file = nil )
         source = nil
         
         if file.nil? then
            source = new( File.open(descriptor), descriptor )
         else
            source = new( file, descriptor )
         end
         
         return source
      end
      
      
      
       
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :descriptor    # Some object describing where our input comes from
      attr_reader :length        # Character length of the text
      
      def initialize( stream, descriptor = nil )
         @stream        = stream
         @descriptor    = descriptor
         @pending       = ""
         @codes         = []
         @eol_positions = []         
         @eols          = 0
         
         @last_position  = -1
         @last_located   = -1
         @last_eol_index = 0
         
         @commit_position     = -1
         @commit_eol_baseline = 0
      end
      
      
      #
      # []
      #  - returns the character code at the specified position
      
      def []( position )
         read_through( position ) or return nil
         @last_position = position
         return @codes[position]
      end

      
      #
      # each_character()
      #  - calls your block once for each character in the Source, passing:
      #     - position
      #     - code
      #     - line_number
      #     - column_number
      
      def each_character()
         position = 0
         while @stream || position < @codes.length 
            while position < @codes.length
               yield( position, @codes[position], line_number(position), column_number(position) )
               position += 1
            end
            
            read_through( position )
         end
      end
      
      
      #
      # commit()
      #  - discards storage (only) for codes on or before the specified position
      #  - useful for streaming operations, to keep old data from filling up memory
      
      def commit( position )
         return true if position <= @commit_position
         assert( read_through(position), "can't commit a position that can't be read!" )
         
         eol_index = line_index(position) - @commit_eol_baseline
         @commit_eol_position = @eol_positions[position]
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Position determination
    #---------------------------------------------------------------------------------------------------------------------

      #
      # line_number()
      #  - returns the line number of the specified position, or of the last one read
      
      def line_number( position = nil )
         return line_index(position) + 1
      end
      
      
      #
      # column_number()
      #  - returns the column number of the specified position, or of the last one read
      
      def column_number( position = nil )
         return column_index(position) + 1
      end
                  
      
      #
      # line_index()
      #  - returns the line index of the specified position, or of the last one read
      
      def line_index( position = nil )
         position = @last_position if position.nil?
         return @last_eol_index if position == @last_located
         
         assert( read_through(position), "you have requested a line index for a position that does not exist!" )
         
         eol_index = nil
         
         #
         # First check if we are on the same line as last time -- or a following line.  We'll also check
         # if we are on the last line, as it is easy to check.

         if @eols == 0 || (@eols > 0 && position > @eol_positions[-1]) then
            eol_index = @eols
         elsif position > @last_located then
            if @last_eol_index < @eols && position <= @eol_positions[@last_eol_index] then
               eol_index = @last_eol_index
            elsif @last_eol_index + 1 < @eols && position <= @eol_positions[@last_eol_index + 1] then
               eol_index = @last_eol_index + 1
            end
         end
         
         
         #
         # If no answer, binary search for the eol_index.

         if eol_index.nil? then
            first = 0
            last  = @eols - 1

            while last > first
               middle = ((last + first) / 2).ceil

               if position > @eol_positions[middle] then
                  first = (first == middle ? first + 1 : middle)
               elsif position <= @eol_positions[middle]
                  last  = (last == middle  ? last - 1 : middle)
               end
            end

            eol_index = first
         end
         
         
         #
         # Finish up and return.

         if eol_index.nil? then
            bug( "what does this mean?" )
         else
            @last_located   = position
            @last_eol_index = eol_index
         
            return @last_eol_index
         end
      end
      
      
      #
      # column_index()
      #  - returns column index for the specified position
      #  - you can pass in the line index, if you already know it, to save time
      
      def column_index( position )
         position  = @last_position if position.nil?
         eol_index = line_index(position)

         if eol_index == 0 then
            return position 
         else
            return position - @eol_positions[eol_index - 1] - 1
         end
      end
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Stream management
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      #
      # read_through()
      #  - reads Unicode characters through the specified position
      
      def read_through( position )
         old_length = @codes.length
         
         #
         # Read UTF8 data while there is input available.  We read in small packets, then convert the
         # data to Unicode character codes.  If we read a partial character code, String.unpack() will
         # throw an ArgumentError, so we'll slice off one character at a time until we get something
         # that works.  Any such sliced-off data will be stored on @pending for next time.
         
         if @stream then
            begin
               while @codes.length <= position
                  if utf8 = @stream.readpartial(128) then
                     utf8 = @pending + utf8
                     @pending = ""
               
                     codes = []
                     while codes.empty? and !utf8.empty?
                        begin
                           codes = utf8.unpack("U*")
                        rescue ArgumentError
                           @pending = utf8.slice!(-1..-1) + @pending
                        end
                     end
               
                     @codes.concat( codes ) unless codes.empty?
                  end
               end
            rescue EOFError
               @stream.close()
               @stream = nil
            end
            
            #
            # Update the list of EOL positions for the new data.

            if @codes.length > old_length then
               old_length.upto(@codes.length - 1) do |i|
                  @eol_positions << i if @codes[i] == 10
               end

               @eols = @eol_positions.length
            end
         end
         
         return @codes.length > position
      end
    
      
      
   end # Source
   


end  # module Artifacts
end  # module Scanner
end  # module RCC
