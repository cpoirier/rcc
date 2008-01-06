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
require "#{$RCCLIB}/plan/predicates/predicate.rb"

module RCC
module Plan
module Predicates

 
 #============================================================================================================================
 # class TryIt
 #  - a predicate that indicates the symbol is worth trying

   class TryIt < Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( insert = true, replace = true )
         super( insert, replace )
      end
      
   end # TryIt
   


end  # module Predicates
end  # module Plan
end  # module RCC
 