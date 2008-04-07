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
 # class SelectorBranch
 #  - a base class for things that select nodes from an ASN as part of a transformation

   class SelectorBranch < Util::ExpressionForms::BranchPoint
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
    
      #
      # apply()
      #  - for a SelectorBranch, we collect all resulting nodes
      
      def apply( nodes )
         traverse(nodes) do |element, nodes|
            element.apply( nodes )
         end
      end
      
      
      #
      # assign()
      
      def assign( search_nodes, result_nodes )
         traverse(search_nodes) do |element, nodes|
            element.assign( nodes, result_nodes )
         end
      end
      
      
      #
      # append()
      
      def append( search_nodes, result_nodes )
         traverse(search_nodes) do |element, nodes|
            element.append( nodes, result_nodes )
         end
      end
      

      #
      # targets()
      #  - returns any target? elements
      
      def targets()
         targets = []
         
         each_element() do |branch|
            if target = branch.target then
               targets << target
            end
         end
         
         return targets
      end


      #
      # traverse()
      #  - internal routine that drives the processing of this sequence
      #  - supply a block to do the particular element work
      
      def traverse( nodes )
         scalar = !nodes.is_an?(Array)
         
         results = []
         self.each_element do |element|
            result = yield( element, nodes )
            scalar = false if result.is_an?(Array)
            results |= result.to_a
         end
         
         if scalar && results.length <= 1 then
            return results.empty? ? nil : results[0]
         else
            return results
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         show_separator = false
         self.branches.each do |element|
            stream << " or " if show_separator
            stream << "(" << element << ")"
            
            show_separator = true
         end
      end
      
      
   end # SelectorBranch
   


end  # module Transformations
end  # module Plan
end  # module RCC


