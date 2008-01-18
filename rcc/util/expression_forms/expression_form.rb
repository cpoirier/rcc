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

module RCC
module Util
module ExpressionForms

 
 #============================================================================================================================
 # class ExpressionForm
 #  - base class fo ExpressionForm elements

   class ExpressionForm
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
      end
      
      
      #
      # paths()
      #  - returns an BranchPoint of ExpressionForms indicating all possible paths through this ExpressionForm
      
      def paths()
         return BranchPoint.new(self)
      end
      
      
      #
      # +()
      #  - returns a Sequence containing this element and the one you supply
      
      def +( rhs )
         return Sequence.new( self, rhs )
      end
      
      
      #
      # elementize()
      #  - returns an ExpressionForm, always
      
      def elementize( element )
         return element.is_an?(ExpressionForm) ? element : Leaf.new(element)
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
      end
      
      
      #
      # element_count()
      #  - returns the number of times your block will be called during each_elements
      
      def element_count()
         return 0
      end


      #
      # display()
      
      def display( stream )
         stream << self.class.name.split("::")[-1].downcase << ": "
         stream << "\n" if element_count() != 1
         
         stream.indent do
            self.each_element do |element|
               element.display( stream )
            end
         end
         
         stream.end_line()
      end

      
   end # ExpressionForm




 #============================================================================================================================
 # class Element
 #  - an ExpressionForm that holds non-ExpressionForm data within an ExpressionForm
 
   class Element < ExpressionForm
      attr_reader :datum
      
      def initialize( datum )
         @datum = datum
      end
      
      
      #
      # each_element()
      #  - calls your block once for every contained element
      
      def each_element()
         yield( @datum )
      end


      
   end
      

    


end  # module ExpressionForms
end  # module Util
end  # module RCC


require "#{$RCCLIB}/util/expression_forms/branch_point.rb"
require "#{$RCCLIB}/util/expression_forms/sequence.rb"
require "#{$RCCLIB}/util/expression_forms/repeater.rb"