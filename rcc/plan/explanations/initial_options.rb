#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"
require "rcc/plan/explanations/explanation.rb"

module RCC
module Plan
module Explanations

 
 #============================================================================================================================
 # class InitialOptions
 #  - base class for things that explain why actions where produced the way they were

   class InitialOptions < Explanation
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( options )
         @options = options
      end
      
      
      def to_s()
         return "Option summary: #{@options.keys.collect{|symbol_name| @options[symbol_name].length.to_s + " for " + Symbol.describe(symbol_name) }.join("; ")}"
      end
      
      
   end # InitialOptions
   



end  # module Explanations
end  # module Plan
end  # module Rethink

