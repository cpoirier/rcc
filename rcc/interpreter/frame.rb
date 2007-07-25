#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"

module RCC
module Interpreter

 
 #============================================================================================================================
 # class Frame
 #  - a Frame on the Interpreter stack

   class Frame
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :state
      attr_reader :node
      
      def initialize( state, node )
         @state = state
         @node  = node
      end
      
      
      
      
      
      
      
   end # Frame
   


end  # module Interpreter
end  # module Rethink
