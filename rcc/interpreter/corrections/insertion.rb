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
 # class Insertion
 #  - represents a single token insertion into the source text

   class Insertion < Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :inserted_token
      
      def initialize( inserted_token, recovery_context, previous_correction, position_number, correction_penalty = 0 )
         super( recovery_context, previous_correction, position_number, correction_penalty )
         @inserted_token = inserted_token
      end
      
      
      #
      # intrinsic_cost()
      #  - returns the intrinsic cost of this type of correction
      
      def intrinsic_cost()
         return 2
      end
      
      
      #
      # inserts_token?()
      #  - returns true if this correction inserts a token into the stream
      
      def inserts_token?()
         return true
      end
      
      
      
      
   end # Correction
   



end  # module Corrections
end  # module Interpreter
end  # module Rethink

