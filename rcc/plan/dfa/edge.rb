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
module Plan
module DFA

 
 #============================================================================================================================
 # class Edge
 #  - an Edge that links on Point to another along a set of inputs 

   class Edge
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :points

      def initialize( inputs, vectors, target = nil )
         @inputs  = inputs
         @vectors = vectors
         @target  = target
      end

      attr_accessor :target
      attr_reader   :vectors
      attr_reader   :inputs

      def display( stream = $stdout )
         stream << " --- "
         stream << @inputs.join(",")
         stream << " | "
         stream << @vectors.join(",")
         stream << " ---> "
         stream.indent(" ") do
            @target.display( stream )
         end
      end

      def cycle?()
         return false
      end

      def dup()
         return self.class.new( @inputs.dup, @vectors.dup, @target.nil? ? nil : @target.dup )
      end

   end # Edge
   



end  # module DFA
end  # module Plan
end  # module RCC
