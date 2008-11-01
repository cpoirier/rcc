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
 # class ExistsPredicate
 #  - a predicate that picks data based on the existence of results from a selector run against the nodes

   class ExistsPredicate < Predicate
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :selector
      
      def initialize( selector )
         @selector = selector
      end
      
      
      #
      # apply()
      
      def apply( nodes )
         Predicate.apply(nodes) do |nodes|
            return nodes.select{|node| !@selector.apply([node]).empty? }
         end
      end
      
      
      
      #
      # display()
      
      def display( stream = $stdout )
         super(stream) do
            stream << "!" << @predicate
         end
      end
      
      
   end # ExistsPredicate
   


end  # module Transformations
end  # module Plan
end  # module RCC
