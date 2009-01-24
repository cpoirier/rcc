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



class Time
   
   #
   # Time.measure()
   #  - returns the duration of the supplied block in seconds (floating point)

   def Time.measure()
      start = Time.now
      yield()
      return Time.now - start
   end

   #
   # Time.measure_get()
   #  - returns the duration and the value from a get
   
   def Time.measure_get()
      start = Time.now
      got = yield()
      return [Time.now - start, got]
   end
   
   #
   # Time.log_duration()
   #  - measure()s your block and outputs the duration, if appropriate
   #  - your message should have a %f where you want the duration included
   
   def Time.log_duration( label, stream = $stdout, format = "TIME %s: %fs" )
      wanted = (stream.respond_to?(:[]) ? stream[:durations] : nil)
      
      if wanted && (wanted.member?(:all) || wanted.member?(label)) then
         duration = Time.measure { yield() }
         stream.puts sprintf( format, label, duration )
      else
         yield()
      end
   end
   
end

