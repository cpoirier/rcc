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


   def max( a, b )
      a > b ? a : b
   end

   def min( a, b )
      a < b ? a : b
   end

   def once()
      yield()
   end

   def forever()
      while true
         yield()
      end
   end

   def ignore_errors( *error_classes )
      begin
         yield()
      rescue Exception => e
         raise e unless error_classes.empty? or error_classes.member?(e.class)
         return false
      end
      
      return true
   end
   
   def with_context_variables( pairs = {} )
      old = pairs.keys.each{ |name| Thread.current[name] }
      begin
         pairs.each{ |name, value| Thread.current[name] = value }
         yield( )
      ensure
         old.each{ |name, value| Thread.current[name] = value }
      end      
   end
   
   def with_context_variable( name, value )
      old = Thread.current[name]
      begin
         Thread.current[name] = value
         yield()
      ensure
         Thread.current[name] = old
      end
   end
   
   def context_variable( name )
      return Thread.current[name]
   end
   
   

   

