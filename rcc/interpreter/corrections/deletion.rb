#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Interpreter
module Corrections

 
 #============================================================================================================================
 # class Deletion
 #  - represents a single token insertion into the source text

   class Deletion < Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( recovery_context, previous_correction, position_number, correction_penalty = 0 )
         super( recovery_context, previous_correction, position_number, correction_penalty )
      end
            
      #
      # intrinsic_cost()
      #  - returns the intrinsic cost of this type of correction
      
      def intrinsic_cost()
         return 3
      end
      
      
      
   end # Deletion
   



end  # module Corrections
end  # module Interpreter
end  # module Rethink

