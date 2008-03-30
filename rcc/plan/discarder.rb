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
require "#{$RCCLIB}/plan/production.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class Discarder
 #  - a Production that results in a Discard instead of a Reduce on completion, meaning its data will immediately stop
 #    affecting the parse

   class Discarder < Production
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------


      def initialize( number, name, symbols, slots, associativity, priority, ast_class )
         super( number, name, symbols, slots, associativity, priority, ast_class, false )
      end
      
      def discard?()
         return true
      end
      
      
   end # Discarder
   





end  # module Plan
end  # module RCC
