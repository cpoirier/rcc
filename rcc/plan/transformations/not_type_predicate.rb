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
require "#{$RCCLIB}/plan/transformations/predicate.rb"

module RCC
module Plan
module Transformations
 
 
 #============================================================================================================================
 # class NotTypePredicate
 #  - a predicate that picks data from a set based on Type

   class NotTypePredicate < Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :type_name
      
      def initialize( type_name )
         @type_name = type_name
      end
      
      
      #
      # apply()
      
      def apply( nodes )
         return nodes.select {|node| node.type != @type_name }
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         super(stream) do
            stream << "!" << @type_name
         end
      end
      
      
   end # NotTypePredicate
   


end  # module Transformations
end  # module Plan
end  # module RCC
