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
 # class Deletion
 #  - represents a single token insertion into the source text

   class Deletion < Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :deleted_token
      
      def initialize( deleted_token, unwind_limit, recovery_context, penalty = 0 )
         super( unwind_limit, recovery_context, penalty )
         @deleted_token  = deleted_token
      end
      
            
      #
      # intrinsic_cost()
      #  - returns the intrinsic cost of this type of correction
      
      def intrinsic_cost()
         return 3
      end
      
      
      #
      # deletes_token?()
      #  - returns true if this correction deletes a token from the stream
      
      def deletes_token?()
         return true
      end
      
      
      #
      # signature()
      
      def signature()
         return "#{@deleted_token.rewind_position}:#{@deleted_token.follow_position}:#{Parser.describe_type(@deleted_token.type)}:"
      end
      
      
      
   end # Deletion
   



end  # module Artifacts
end  # module Interpreter
end  # module Rethink

