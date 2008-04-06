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
 # class InvertedPredicate
 #  - a predicate that picks data based on what another Predicate doesn't pick

   class InvertedPredicate < Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :predicate
      
      def initialize( predicate )
         @predicate = predicate
      end
      
      
      #
      # apply()
      
      def apply( nodes )
         return nodes - @predicate.apply(nodes)
      end
      
      
      
      #
      # display()
      
      def display( stream = $stdout )
         super(stream) do
            stream << "!" << @predicate
         end
      end
      
      
   end # InvertedPredicate
   


end  # module Transformations
end  # module Plan
end  # module RCC
