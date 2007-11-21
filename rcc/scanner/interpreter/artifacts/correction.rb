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
module Scanner
module Interpreter
module Artifacts

 
 #============================================================================================================================
 # class Correction
 #  - base class for a source correction created during error recovery

   class Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :recovery_context   # the position within the source at which the initial error occurred
      attr_reader :unwind_limit
      
      def initialize( unwind_limit, recovery_context, penalty = 0 )
         @recovery_context = recovery_context
         @unwind_limit     = unwind_limit
         @penalty          = penalty
      end
      
      #
      # original_error_position
      #  - returns the *source* position of the original error that caused this Correction
      
      def original_error_position()
         return @recovery_context.next_token.start_position
         # discarded because probably wrong: return @recovery_context.stream_position
      end
      
      alias earliest_recovery_position original_error_position
      
      
      #
      # cost()
      #  - returns the cost of this particular Correction
      
      def cost()
         return intrinsic_cost() + @penalty
      end
      
      
      #
      # intrinsic_cost()
      #  - returns the intrinsic cost of this type of Correction
      
      def intrinsic_cost()
         return 0
      end
      
      
      #
      # inserts_token?()
      #  - returns true if this correction inserts a token into the stream
      
      def inserts_token?()
         return false
      end
      
      
      #
      # deletes_token?()
      #  - returns true if this correction deletes a token from the stream
      
      def deletes_token?()
         return false
      end
      
      
      #
      # signature()

      def signature()
         bug( "you must override Correction.signature()" )
      end
      

      #
      # sample()
      
      def sample()
         if deletes_token?() then
            return @deleted_token.sample
         else
            return @inserted_token.sample
         end
      end
      
      
      #
      # line_number()
      
      def line_number()
         if deletes_token?() then
            return @deleted_token.line_number
         else
            return @inserted_token.line_number
         end
      end


   end # Correction
   



end  # module Artifacts
end  # module Interpreter
end  # module Scanner
end  # module RCC


require "#{$RCCLIB}/scanner/interpreter/artifacts/insertion.rb"
require "#{$RCCLIB}/scanner/interpreter/artifacts/replacement.rb"
require "#{$RCCLIB}/scanner/interpreter/artifacts/deletion.rb"
