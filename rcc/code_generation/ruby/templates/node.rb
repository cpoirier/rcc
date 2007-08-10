#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
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
