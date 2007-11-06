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
module Artifacts

 
 #============================================================================================================================
 # class Replacement
 #  - represents a single token replacement in the source text

   class Replacement < Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :inserted_token
      attr_reader :deleted_token
      
      def initialize( inserted_token, deleted_token, unwind_limit, original_error_position, penalty = 0 )
         super( unwind_limit, original_error_position, penalty )
         @inserted_token = inserted_token
         @deleted_token  = deleted_token
      end
      
      
      #
      # intrinsic_cost()
      #  - returns the intrinsic cost of this type of correction
      
      def intrinsic_cost()
         return 1
      end
      
            
      #
      # inserts_token?
      
      def inserts_token?
         return true
      end
      
      
      #
      # deletes_token?()
      #  - returns true if this correction deletes a token from the stream
      
      def deletes_token?()
         return true
      end
      
      
   end # Replacement
   



end  # module Artifacts
end  # module Interpreter
end  # module Rethink

