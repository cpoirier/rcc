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
 # class SelectorSequence
 #  - a base class for things that select nodes from an ASN as part of a transformation

   class SelectorSequence < Util::ExpressionForms::Sequence
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------


      def <<( element )
         if defined?(@lhs_predicate) and @lhs_predicate.exists? then
            @predicate << element
         else
            super
         
            last_element = self.elements[-1]
            if last_element.is_a?(Selector) and last_element.target? then
               @predicate = SelectorSequence.new()
            end
         end
      end


      #
      # apply()
      #  - for a SelectorSequence, we chain through our selectors and return only the last produced set of nodes
      
      def apply( nodes )
         traverse(nodes){|element, nodes| element.apply(nodes)}
      end
      
      
      
      #
      # assign()
      #  - assigns the results of an RHS selector to that denoted by this one
      
      def assign( search_nodes, result_nodes )
         traverse(search_nodes) do |element, nodes|
            element.assign( nodes, result_nodes )
            break if element.target?
         end
         
         warn_nyi( "what should assign() return?  should results of a sequence be usable in a branch that isn't otherwise finished?" )
      end


      #
      # append()
      
      def append( search_nodes, result_nodes )
         traverse(search_nodes) do |element, nodes|
            element.append( nodes, results_nodes )
            break if element.target?
         end
         
         return nil
      end
      
      
      #
      # unset()
      
      def unset( search_nodes )
         traverse(search_nodes) do |element, nodes|
            element.unset( nodes )
            break if element.target?
         end
         
         return nil
      end
      
      #
      # targets()
      #  - returns any target? elements
      
      def targets()
         targets = []
         
         each_element() do |element|
            if targets = element.targets then
               break
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
         
         self.each_element do |element|
            results = yield( element, nodes )
            scalar  = false if results.is_an?(Array)
            nodes   = results
         end
         
         if scalar && nodes.length <= 1 then
            return nodes.empty? ? nil : nodes[0]
         else
            return nodes
         end
      end
      
      
      #
      # display()
      
      def display( stream = $stdout )
         show_separator = false
         self.elements.each do |element|
            stream << " then " if show_separator
            stream << element
            
            show_separator = true
         end
      end
      
      
   end # Selector
   


end  # module Transformations
end  # module Plan
end  # module RCC


