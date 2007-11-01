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
 # class CheckErrorType
 #  - indicates the recovery should only be considered if the error token has the specified type

   class CheckErrorType < Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :error_type
      
      def initialize( error_symbol, insert = true, replace = true )
         super( insert, replace )
         
         @error_type = error_symbol.name
      end
      
   end # CheckErrorType
   


end  # module Predicates
end  # module Plan
end  # module Rethink
 