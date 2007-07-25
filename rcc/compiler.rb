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
module module

 
 #============================================================================================================================
 # class Compiler
 #  - the master controller for rcc system
 #  - manages parsing of the grammar, construction of the model, creation of the plan, and output to a particular language
 

   class Compiler
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @rule_names       = {}
         @rules_and_groups = []
      end
      
   end # Compiler
   


end  # module module
end  # module Rethink
