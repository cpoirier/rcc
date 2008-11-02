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
 # class Node
 #  - base class for anything that can be held on the Parser stack

   class Node 
      
      attr_reader   :type       # The symbolic name of this Node within the overall grammar
      attr_accessor :value      # Any value assigned to this Node by a processor
      
      def initialize( type, value = nil )
         @type  = type
         @value = value
      end

   end # Node
 


   

%%MODULE_FOOTER%%
