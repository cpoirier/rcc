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
require "#{$RCCLIB}/util/expression_forms/sequence.rb"


module RCC
module Plan 
module Transformations
 
 
 #============================================================================================================================
 # class PredicateAnd
 #  - a base class for things that select nodes from an ASN as part of a transformation

   class PredicateAnd < Util::ExpressionForms::Sequence
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------


      #
      # apply()
      #  - for PredicateAnd, we take the intersection of all produced nodes
      
      def apply( nodes )
         self.each_element do |element|
            nodes &= element.apply( nodes )
         end
         
         return nodes
      end
      
      
      
      #
      # display()
      
      def display( stream = $stdout )
         show_separator = false
         self.elements.each do |element|
            stream << "&" if show_separator
            stream << element
            
            show_separator = true
         end
      end
      
      
   end # PredicateAnd
   


end  # module Transformations
end  # module Plan
end  # module RCC


