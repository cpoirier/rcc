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
 # class Correction
 #  - base class for a source correction created during error recovery

   class Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :original_error_position   # the position within the source at which the initial error occurred
      attr_reader :unwind_limit
      
      def initialize( unwind_limit, original_error_position, penalty = 0 )
         @original_error_position = original_error_position
         @unwind_limit = unwind_limit
         @penalty      = penalty
      end
      
      
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

      
   end # Correction
   



end  # module Artifacts
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/artifacts/insertion.rb"
require "#{$RCCLIB}/interpreter/artifacts/replacement.rb"
require "#{$RCCLIB}/interpreter/artifacts/deletion.rb"
