#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Interpreter
module Markers

 
 #============================================================================================================================
 # class RecoveryContext
 #  - a marker that tracks an error recovery

   class RecoveryContext
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( error_position, seed_positions = nil )
         @error_position = error_position    # a Position where the error was discovered
         @positions_seen = {}                # a hash of signatures for Positions we should not retry during recovery
         
         unless seed_positions.nil?
            seed_positions.each do |seed_position|
               @positions_seen[seed_position.signature] = true
            end
         end
      end
      
      
      #
      # position_seen?
      #  - returns true if the supplied position has already been tried in this recovery 
      
      def position_seen?( position )
         return true if @positions_seen.member?(position.signature)
         
         if @error_position.recovery_context.nil? then
            return false
         else
            return @error_position.recovery_context.position_seen?(position)
         end
      end
      
      
      #
      # mark_position_seen()
      #  - adds the specified position to our record of those seen during this recovery (and that should not be retried)
      
      def mark_position_seen( position )
         @positions_seen[position.signature] = true
      end
      
      
      
      
   end # RecoveryContext
   


end  # module Markers
end  # module Interpreter
end  # module Rethink
