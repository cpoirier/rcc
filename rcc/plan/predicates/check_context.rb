#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/plan/predicates/predicate.rb"

module RCC
module Plan
module Predicates

 
 #============================================================================================================================
 # class CheckContext
 #  - a predicate that refers the system to another State for answers
 #  - used when an Item is ready for REDUCE, and we need to verify an inserted token will eventually be used

   class CheckContext < Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( insert = true, replace = true )
         super( insert, replace )
      end
      
   end # CheckContext
   


end  # module Predicates
end  # module Plan
end  # module Rethink
 