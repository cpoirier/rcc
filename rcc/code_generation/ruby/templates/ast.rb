#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================


require "#{File.dirname(__FILE__)}/node.rb" 


%%MODULE_HEADER%%
 

 #============================================================================================================================
 # class ASNode
 #  - base class for Abstract Syntax Tree nodes produced for the grammar

   class ASNode < Node
      
      attr_reader :type    # The symbolic name of this Node within the overall grammar
      attr_reader :slots   # A hash of our slots, symbol => node
      
      def initialize( type, slot_names = [] )
         super( type, nil )
         @slots = Struct::new( *slot_names )
      end

   end # ASNode
   
   
   
 %%ASNs%%

   

%%MODULE_FOOTER%%
