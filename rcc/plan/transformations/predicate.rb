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
 # class Predicate
 #  - a base class for things that eliminate nodes from Selector results set

   class Predicate < Selector
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         super( false )
      end
      
      
      #
      # apply()
      
      def apply( nodes )
         bug( "you must override Predicate.apply()" )
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         @selector.display( stream )
         if block_given? then
            stream << "[" 
            yield()
            stream << "]"
         end
      end
      
      
   end # Predicate
   


end  # module Transformations
end  # module Plan
end  # module RCC


require "#{$RCCLIB}/plan/transformations/predicate_and.rb"
require "#{$RCCLIB}/plan/transformations/predicate_or.rb"

require "#{$RCCLIB}/plan/transformations/inverted_predicate.rb"
require "#{$RCCLIB}/plan/transformations/type_predicate.rb"
require "#{$RCCLIB}/plan/transformations/not_type_predicate.rb"
