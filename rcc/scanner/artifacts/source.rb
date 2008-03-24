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
         
         @last_position  = -1
         @last_located   = -1
         @last_eol_index = 0
         
         @commit_position                  = -1    # The position number last discarded
         @commit_eol_positions_discarded   = 0     # The number of @eol_positions already discarded
         @commit_first_line_start_position = 0     # The position corresponding to the first character of the first line in @eol_positions
      end
      
      
      def read_so_far()
         return @codes.length + @commit_position + 1
      end
      
      def committed_through()
         return @commit_position
      end
      
      
      
      #
      # []
      #  - returns the character code at the specified position
      
      def []( position )
         read_through( position ) or return nil
         @last_position = position
         return @codes[position - (@commit_position + 1)]
      end

      
      #
      # each_character()
      #  - calls your block once for each character in the Source, passing:
      #     - position
      #     - code
      #     - line_number
      #     - column_number
      #  - this routine should be a bit faster than doing the work yourself
      
      def each_character( position = 0 )
         line_number   = line_number(position)
         column_number = column_number(position)
         
         while true
            while @codes.length > position - (@commit_position + 1)
               code = @codes[position - (@commit_position + 1)]     
               yield( position, code, line_number, column_number )  

               if code == 10 then
                  line_number  += 1
                  column_number = 1
               else
                  column_number += 1
               end
               
               position += 1
            end
            
            break if @stream.nil?
            read_through( position )
         end
      end
      
      #
      # each_character_slow()
      #  - primarily for testing purposes, does the same as each_character(), but using all
      #    the Source interface for the work
      
      def each_character_slow( position = 0 )   
         while (@stream || position < read_so_far())
            while position < read_so_far()
               yield( position, self[position], line_number(position), column_number(position) )
               @last_position = position
               position += 1
            end
         
            read_through( position )
         end
      end
      
      
      #
      # line_number()
      #  - returns the line number of the specified position, or of the last one read
      
      def line_number( position = nil )
         return eol_index(position) + @commit_eol_positions_discarded + 1
      end
      
      
      #
      # column_number()
      #  - returns the column number of the specified position, or of the last one read
      
      def column_number( position = nil )
         position  = @last_position if position.nil?
         eol_index = eol_index(position)
         
         if eol_index == 0 then
            return position - @commit_first_line_start_position + 1
         else
            return position - @eol_positions[eol_index - 1] 
         end
      end
      
      
      #
      # commit()
      #  - discards storage (only) for codes on or before the specified position
      #  - useful for streaming operations, to keep old data from filling up memory
      
      def commit( position = nil )
         position = @last_position if position.nil?
         return if position <= @commit_position
         assert( read_through(position), "can't commit a position that can't be read!" )
                  
         #
         # First up, collect location information on the position we are about to commit.  This
         # will be used to patch up future location calculations, to account for the commmitted
         # data.
         
         eol_index                 = eol_index(position)
         on_eol                    = (eol_index < @eol_positions.length and @eol_positions[eol_index] == position)
         eol_discard_count         = eol_index + (on_eol ? 1 : 0)
         first_line_start_position = on_eol ? @eol_positions[eol_index] + 1 : (eol_index > 0 ? @eol_positions[eol_index - 1] + 1 : @commit_first_line_start_position)
         
         #
         # Discard @codes and @eol_positions and patch up the offsets.
         
         @codes.slice!( 0..(position - @commit_position - 1) )
         @eol_positions.slice!( 0..(eol_discard_count - 1) )
         
         @commit_position                   = position
         @commit_eol_positions_discarded   += eol_discard_count
         @commit_first_line_start_position  = first_line_start_position
         
         @last_position  = -1
         @last_located   = -1
         @last_eol_index = 0
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Location determination
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      
      #
      # eol_index()
      #  - returns the eol index of the specified position, or of the last one read
      #  - you can't access eol_index for committed positions!
      
      def eol_index( position = nil )
         position = @last_position if position.nil?
         return nil if position.nil?
         return @last_eol_index if position == @last_located
         
         assert( position > @commit_position, "you can't get location information for a committed position!" )
         assert( read_through(position)     , "you can't get location information for a position that does not exist!" )
         
         eol_index = nil
         
         #
         # First check if we are on the same line as last time -- or a following line.  We'll also check
         # if we are on the last line, as it is easy to check.

         if @eol_positions.length == 0 || position > @eol_positions[-1] then
            eol_index = @eol_positions.length
         elsif position <= @eol_positions[-1] && (@eol_positions.length == 1 || position > @eol_positions[-2]) then
            eol_index = @eol_positions.length - 1
         elsif position <= @eol_positions[0] then
            eol_index = 0
         elsif @last_located && position > @last_located then
            if @last_eol_index < @eol_positions.length && position <= @eol_positions[@last_eol_index] then
               eol_index = @last_eol_index
            elsif @last_eol_index + 1 < @eol_positions.length && position <= @eol_positions[@last_eol_index + 1] then
               eol_index = @last_eol_index + 1
            end
         end
         
         #
         # If no answer, binary search for the eol_index.

         if eol_index.nil? then
            first  = 0
            last   = @eol_positions.length - 1

            while eol_index.nil? and first < last
               middle = ((last + first) / 2).ceil
               
               if position == @eol_positions[middle] then
                  eol_index = middle
               elsif position < @eol_positions[middle] then
                  if middle == 0 or position > @eol_positions[middle-1] then
                     eol_index = middle
                  else
                     last = (last == middle ? last - 1 : middle)
                  end
               else
                  first = (first == middle ? first + 1 : middle)
               end
            end
         end
         
         #
         # Finish up and return.

         if eol_index.nil? then
            bug( "what does this mean at #{position}?" )
         else
            @last_located   = position
            @last_eol_index = eol_index
         
            return @last_eol_index
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
         return true if position < read_so_far()
         old_length = @codes.length
         
         #
         # Read UTF8 data while there is input available.  We read in small packets, then convert the
         # data to Unicode character codes.  If we read a partial character code, String.unpack() will
         # throw an ArgumentError, so we'll slice off one character at a time until we get something
         # that works.  Any such sliced-off data will be stored on @pending for next time.
         
         if @stream then
            begin
               until position < read_so_far() 
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
                  @eol_positions << @commit_position + 1 + i if @codes[i] == 10
               end
            end
         end
         
         return position < read_so_far()
      end
    
      
      
   end # Source
   


end  # module Artifacts
end  # module Scanner
end  # module RCC
