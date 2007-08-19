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

 
 #============================================================================================================================
 # class Error
 #  - records the data for a parse error we were unable to recover from

   class Error
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :bad_token
      attr_reader :expected_tokens
      
      def initialize( bad_token, expected_tokens )
         @bad_token         = bad_token
         @expected_tokens   = expected_tokens
      end
      
      def position() 
         return bad_token.start_position
      end
      
      
      
   end # Error
   


end  # module Interpreter
end  # module Rethink
