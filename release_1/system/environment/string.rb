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


class String
   
   attr_accessor :source
   
   #
   # Converts the string to a plural form.  It's simple
   # stupid concatenation...

   def pluralize( count = 2, plural_form = nil )
      if count == 1 then
         return self
      else
         if plural_form.nil? then
            if self[-1..-1] == "y" then
               return self[0..-2] + "ies"
            else
               return self + "s"
            end
         else
            return plural_form
         end
      end
   end


   #
   # each_index_of()
   #  - calls your block with each position of the search string
   
   def each_index_of( search, pos = 0 )
      while next_pos = ruby_index( search, pos )
         yield( next_pos )
         pos = next_index + 1
      end
   end


   #
   # escape()
   #  - returns a string with newline etc. escaped
   
   def escape()
      self.inspect.slice(1..-2).gsub("\\\"", "\"").gsub("\\'", "'")
   end
   
   
   #
   # <<
   #  - adds unicode character code support to the standard << 

   alias ruby_append <<
   
   def <<( data )
      if data.is_a?(Numeric) then
         self << [data].pack("U*")
      else
         ruby_append( data )
      end
   end
   
   
   def write( data )
      ruby_append( data )
   end

end


