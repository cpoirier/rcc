#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright (C) 2007-2008 Chris Poirier (cpoirier@gmail.com)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation 
# files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
# modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE 
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR 
# IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#================================================================================================================================


#
# class ContextStream
#  - a wrapper for STDOUT/STDERR that provides a bit of context-sensitivity for output processing.

class ContextStream
   attr_reader :stream
   attr_reader :indent
   
   def initialize( stream, indent = "" )
      @real_stream = stream
      @stream      = stream
      @indent      = indent
      @pending     = true
      @properties  = {}
   end
   
   
   #
   # ::indent_with()
   
   def self.indent_with( stream, additional = "   " )
      if stream then
         stream.indent(additional) { yield(stream) }
      else
         yield(stream)
      end
   end

   
   #
   # ::buffer_with()
   
   def self.buffer_with( stream, commit_if_not_discarded = true )
      if stream then
         stream.buffer(commit_if_not_discarded) { yield() }
      else
         yield()
      end
   end
   
   
   #
   # indent()
   #  - any output during your block will be indented from the context
   
   def indent( additional = "   " )
      old_indent = @indent
      begin
         additional = "   " * additional if additional.is_a?(Numeric)
         @indent += additional
         return yield( self )
      ensure
         @indent = old_indent
      end
   end
   

   #
   # with()
   #  - applies a set of name => value properties for the length of your block
   #  - properties can be retrieved with property()
   
   def with( pairs )
      old = pairs.keys.each{ |name| @properties[name] }
      begin
         pairs.each{ |name, value| @properties[name] = value }
         yield( )
      ensure
         old.each{ |name, value| @properties[name] = value }
      end      
   end
   
   
   #
   # []
   #  - returns the named property's current value, or nil
   
   def []( name )
      return @properties[name]
   end
   
   
   #
   # []=
   #  - sets a named property (without any scope management)
   
   def []=( name, value )
      @properties[name] = value
   end
   
   
   def <<( text )
      if text.is_a?(String) then
         write( text )
      else
         text.display( self )
      end
      self
   end


   def puts( text = "" )
      write( text )
      write( "\n" )
   end

   
   def write( data )
      string = data.to_s
      string = data.inspect if string.nil?
      
      if @pending then
         @stream.write( @indent )
         @pending = false
      end
      
      if string[-1..-1] == "\n" then
         @pending = true
         @stream.write( string.slice(0..-2).gsub("\n", "\n#{@indent}") )
         @stream.write( "\n" )
      else
         @stream.write( string.gsub("\n", "\n#{@indent}") )
      end
   end

   
   def end_line()
      write( "\n" ) unless @pending
   end

   
   def blank_lines( count = 2 )
      end_line()
      count.times { puts }
   end

   
   #
   # buffer()
   
   def buffer( commit_if_not_discarded = true )
      @stream = ""
      
      if block_given? then
         begin
            yield()
         ensure
            if commit_if_not_discarded then
               commit()
            else
               discard()
            end
         end
      end
   end

   
   #
   # commit()
   
   def commit()
      if @stream.object_id != @real_stream.object_id then
         @real_stream.write( @stream )
         @stream = @real_stream
      end
   end

   
   #
   # discard()
    
   def discard()
      @stream = @real_stream
   end
   

   def method_missing( name, *args )
      @stream.send( name, *args )
   end


   #
   # self.hijack_std()
   
   def ContextStream.hijack_std()
      $stdout = ContextStream.new( $stdout ) unless $stdout.is_a?(ContextStream)
      $stderr = ContextStream.new( $stderr ) unless $stderr.is_a?(ContextStream)
   end
   
end # ContextStream


