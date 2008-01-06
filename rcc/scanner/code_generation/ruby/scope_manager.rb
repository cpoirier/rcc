#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

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
