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
module Ruby

 
 #============================================================================================================================
 # class ScopeManager
 #  - a utility for managing variables between 

   class ScopeManager
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( parent_scope )
         @parent_scope    = nil
         @local_variables = {}
      end
      
      
      #
      # []()
      #  - returns the physical name for supplied logical name
      #  - it is a bug to ask for a name you have not define()d
      
      def []( name )
         if @local_variables.member?(name) then
            if @local_variables[name] == 1 then
               return name
            else
               return "#{name}#{@local_variables[name]}"
            end
         elsif @parent_scope.nil? then
            bug( "you have not defined variable [#{name}]" )
         else
            return @parent_scope[name]
         end
      end
      
      
      #
      # define()
      #  - defines the named variable in the current scope
      #  - returns the actual name you should use
      #  - it's a bug to redefine a variable in the current scope
      
      def define( name )
         if @local_variables.member?(name) then
            bug( "you can't redefine variable [#{name}] in the current scope" )
         else
            @local_variables[name] = @parent_scope.count(name) + 1
         end
         
         return self[name]
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Internals
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # count( name )
      #  - returns the current count for the specified name within the whole scope set
      
      def count( name )
         if @local_variables.member?( name ) then
            return @local_variables[name]
         elsif @parent_scope.nil? then
            return 0
         else
            return @parent_scope.count( name )
         end
      end

      
      
   end # ScopeManager
   


end  # module Ruby
end  # module CodeGeneration
end  # module Scanner
end  # module RCC
