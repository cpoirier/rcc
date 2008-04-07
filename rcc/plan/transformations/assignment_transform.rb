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
 # class AssignmentTransform

   class AssignmentTransform < Transform
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( lhs_selector, rhs_selector )
         super( lhs_selector, rhs_selector )
      end
      
      
      #
      # apply()
      #  - performs the transform
      
      def apply( node )
         @lhs_selector.assign( node, @rhs_selector.apply(node) )
      end
      
      
   end # AssignmentTransform
   


end  # module Transformations
end  # module Plan
end  # module RCC
