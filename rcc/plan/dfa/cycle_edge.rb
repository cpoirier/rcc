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
require "#{$RCCLIB}/plan/dfa/edge.rb"


module RCC
module Plan
module DFA

 
 #============================================================================================================================
 # class CycleEdge
 #  - a specialized Edge that marks the beginning of a cycle
 #  - the last Edge in the Cycle will have a nil target 

   class CycleEdge < Edge
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def cycle?()
         return true
      end

      def terminate_cycle()
         work_queue = [self]
         until work_queue.empty?
            edge = work_queue.shift
            if edge.target.exit.nil? and edge.target.edges.empty? then
               edge.target = nil
            else
               work_queue.concat edge.target.edges
            end
         end
      end

      def unroll( terminus )
         copy = Edge.new( @inputs.dup, @vectors.dup, @target.nil? ? nil : @target.dup )
         work_queue = [copy]
         until work_queue.empty?
            edge = work_queue.shift
            if edge.target.nil? then
               edge.target = terminus
            else
               work_queue.concat edge.target.edges
            end
         end

         return copy
      end

   end # CycleEdge
   



end  # module DFA
end  # module Plan
end  # module RCC
