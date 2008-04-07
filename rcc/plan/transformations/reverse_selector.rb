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
 # class ReverseSelector
 #  - a selector that reverse whatever is passed to it

   class ReverseSelector < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( target )
         super( target )
      end
      
      
      #
      # apply()
      #  - applies this selector to a node set, returning the resulting node(s)
      
      def apply( nodes )
         if node.is_an?(Array) then
            return nodes.reverse
         else
            return node
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << " - "
         super
      end
      
      
   end # ReverseSelector
   


end  # module Transformations
end  # module Plan
end  # module RCC
