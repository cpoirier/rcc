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
 # class SelfSelector
 #  - a selector that returns its input verbatim

   class SelfSelector < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( target )
         super( target )
      end
      
      
      #
      # apply()
      #  - applies this selector to a node set, returning the resulting node(s)
      
      def apply( node )
         return node
      end
      
      
      #
      # assign()
      
      def assign( search_nodes, result_nodes )
         return super unless target?
         nyi( nil, "how do we do self-assignment if not done during parse?" )
      end
      
      
      #
      # append()
      
      def assign( search_nodes, result_nodes )
         return super unless target?
         nyi( nil, "what does self-append even mean?" )
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         stream << "."
         super
      end
      
      
   end # SlotSelector
   


end  # module Transformations
end  # module Plan
end  # module RCC
