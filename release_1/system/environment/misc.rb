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
   
   

   

