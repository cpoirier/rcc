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


