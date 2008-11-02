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


%%MODULE_HEADER%%

 
 #============================================================================================================================
 # module Common
 #  - miscellaneous routines and classes useful to all generated classes

   module Common
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Software quality tools
    #---------------------------------------------------------------------------------------------------------------------
    
      class Bug              < Exception; end
      class AssertionFailure < Bug; end

      
      #
      # assert()
      #  - raises an AssertionFailure if the condition is false

      def assert( condition, message )
         raise Common::AssertionFailure.new(message) unless condition
      end


      #
      # bug()
      #  - raises a Bug exception, indicating that something happened that shouldn't have

      def bug( description )
         raise Common::Bug.new( "BUG: " + description )
      end


      #
      # ignore_errors()
      #  - catches any exceptions raised in your block, and returns error_return instead
      #  - returns your block return otherwise

      def ignore_errors( error_return = nil )
         begin
            return yield()
         rescue
            return error_return
         end
      end



    #---------------------------------------------------------------------------------------------------------------------
    # Metrics
    #---------------------------------------------------------------------------------------------------------------------


      #
      # measure()
      #  - returns the duration of the supplied block in seconds (floating point)

      def measure()
         start = Time.now
         yield()
         return Time.now - start
      end
      
      



      
      
   end # Common
   



%%MODULE_HEADER