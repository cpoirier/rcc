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
require "#{$RCCLIB}/plan/transformations/selector.rb"

module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class Transform
 #  - base class for things that represent a transformation

   class Transform
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( lhs_selector, rhs_selector )
         @lhs_selector = lhs_selector
         @rhs_selector = rhs_selector
      end
      
      
      #
      # apply()
      #  - performs the transform
      
      def apply( node )
         bug( "you must override Transform.apply()" )
      end
      
      
   end # Transform
   


end  # module Transformations
end  # module Plan
end  # module RCC


require "#{$RCCLIB}/plan/transformations/assignment_transform.rb"
require "#{$RCCLIB}/plan/transformations/append_transform.rb"
