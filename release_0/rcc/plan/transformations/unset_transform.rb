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
require "#{$RCCLIB}/plan/transformations/transform.rb"

module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class UnsetTransform

   class UnsetTransform < Transform
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( selector )
         super( selector, nil )
      end
      
      
      #
      # apply()
      #  - performs the transform
      
      def apply( node )
         @lhs_selector.unset( node )
      end
      
      
   end # UnsetTransform
   


end  # module Transformations
end  # module Plan
end  # module RCC
