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
require "#{$RCCLIB}/plan/dfa/point.rb"



module RCC
module Plan
module DFA

 
 #============================================================================================================================
 # class Builder
 #  - builds a DFA from an ExpressionForm of SparseRanges

   class Builder
      
      
      #
      # ::build()
      #  - builds a DFA from an ExpressionForm
      
      def self.build( name, expression_form )
         return build_into( Point.new(), name, expression_form )
      end
      
      
      #
      # ::build_into()
      #  - applies an ExpressionForm of SparseRanges into an existing DFA
      
      def self.build_into( start_point, name, expression_form )
         start_point.make( name ) do |p|
            process( expression_form, p )
         end
         
         return start_point
      end
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Processing
    #---------------------------------------------------------------------------------------------------------------------
    
    
      def self.process( form, target )
         return send( form.specialize_method_name("process"), form, target )
      end
      

      def self.process_sequence( sequence, target )
         sequence.each_element do |element| 
            target = process( element, target )
         end
         
         return target
      end
      
      
      def self.process_sparse_range( sparse_range, target )
         return target.make_edge( sparse_range )
      end
      
      
      def self.process_repeater( repeater, target )
         nyi( "support for arbitrarily repeated forms", repeater ) if (repeater.minimum > 1 or repeater.maximum == repeater.minimum)

         #
         # For ? elements, we process normally, but include the root target in the results set.
         
         if repeater.maximum == 1 then
            return target + process( repeater.element, target )
         
         
         #
         # * and + elements are treated as cycles, except that we process the first instance of the + as an edge.
         
         else
            target = process( repeater.element, target ) if repeater.minimum == 1
            
            target = target.make_cycles do
               process( repeater.element, target )
            end
         end
      end
      

      
   end # Builder
   




end  # module DFA
end  # module Plan
end  # module RCC
