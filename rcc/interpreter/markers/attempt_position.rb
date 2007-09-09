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
module PositionMarkers

 
 #============================================================================================================================
 # class AttemptPosition
 #  - a special Position marker used that denotes the root of an Attempt fork
 #  - "replaces" the top-of-stack Position

   class AttemptPosition < GeneralPosition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_accessor :launch_action
      attr_accessor :attempt_depth
      
      def initialize( context, node, state, token_stream, launch_action, expected_productions, error_context = nil, attempt_depth = 0 )
         super( nil, nil, state, token_stream, error_context )
         @launch_action        = launch_action
         @attempt_depth        = attempt_depth
         @expected_productions = expected_productions
      end
      
      
      #
      # in_attempt?
      #  - returns true if this position or one of our context positions is an AttemptPosition
      #  - if true, indicates the parse is currently attempting something
      
      def in_attempt?()
         return true
      end


      #
      # attempt_context
      #  - returns the closest AttemptPosition from the stack
      
      def attempt_context()
         return self
      end
      
      
      #
      # pop()
      #  - tells this Position it is being "popped" from the working set
      #  - pass it the top Position that was popped, so the routine can expect the chain, if necessary
      #  - returns our context Position
      #  - raises AttemptFailed if the production is not on the expected_productions list
      
      def pop( production, top_position = nil )
         unless production.nil? or @expected_productions.nil?
            unless @expected_productions.member?( production ) 
               raise Parser::AttemptFailed.new( production, @expected_productions, top_position )
            end
         end
         
         return @context
      end
      
      
      
      
   end # AttemptPosition
   


end  # module PositionMarkers
end  # module Interpreter
end  # module Rethink


