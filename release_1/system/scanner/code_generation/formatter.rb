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
module Scanner
module CodeGeneration

 
 #============================================================================================================================
 # class Formatter
 #  - provides various formatting and outputting support functions for code generation

   class Formatter
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( output_stream, line_prefix, line_suffix )
         @output_stream = output_stream
         @line_prefix   = line_prefix
         @line_suffix   = line_suffix
      end
      
      
      #
      # <<()
      #  - outputs one or more lines to the underlying stream
      #  - parameter can be an array of strings or an string containing newlines
      
      def <<( parameter )
         if parameter.is_an?(Array) then
            parameter.each do |element|
               self << element
            end
         elsif !parameter.index("\n").nil? then
            self << parameter.split("\n")
         else
            @output_stream.print( @line_prefix )
            @output_stream.print( parameter    )
            @output_stream.puts(  @line_suffix )
         end 
         
         return self
      end
      
      
      #
      # blank_line
      #  - outputs a blank line
      
      def blank_line
         self << ""
      end
      
      
      #
      # indent()
      #  - if you pass a block, temporarily increases the indent of this Formatter and calls your block
      #  - otherwise, returns a new Formatter with a deeper indent
      
      def indent( indent_string = "   " )
         if block_given?() then
            current_prefix = @line_prefix
            begin
               @line_prefix = @line_prefix + indent_string
               yield( self )
            ensure
               @line_prefix = current_prefix
            end
            
            return self
         else
            return self.class.new( @output_stream, line_prefix + indent_string, line_suffix )
         end
      end
      
      
      #
      # columnate()
      #  - generates output from columns of data
      #  - each column can be a string or an array of strings; the former will be used with each of the latter
      
      def columnate( *columns )
         
         #
         # Figure out the output dimensions
         
         rows   = columns.inject(0) {|rows, column| max(rows, column.is_an?(Array) ? column.length : 1 )}
         widths = columns.collect do |column|
            if column.is_an?(Array) then
               column.inject(0) {|width, cell| max(width, cell.length)}
            else
               rows 
               column.length
            end
         end
         
         #
         # Generate the lines of output.  Each element is padded with spaces to make the columns line up.
         
         elements = []
         rows.times do |row|
            columns.each_index do |column_index|
               column = columns[column_index]
               width  = widths[column_index]
               
               if column.is_an?(Array) then
                  elements << column[row].to_s.ljust(width)
               else
                  elements << column.to_s.ljust(width)
               end
            end
            
            self << elements.join
            elements.clear
         end
      end
      
      
      #
      # block()
      #  - outputs a header and (optional) footer, between which it calls your block with an indent()ed Formatter
      #  - headers and footers can be arrays of lines, or a string with newlines
      
      def block( header, footer, indent_string = "   " )
         self << header
         
         self.indent do |indenter|
            yield( indenter )
         end
         
         self << footer
      end
      
   end # Formatter
   


end  # module CodeGeneration
end  # module Scanner
end  # module RCC




