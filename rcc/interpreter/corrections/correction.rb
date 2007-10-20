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
 # class Correction
 #  - base class for a source correction created during error recovery

   class Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :recovery_context
      attr_reader :previous_correction
      attr_reader :previous_unassociated_correction
      attr_reader :position_number
      attr_reader :correction_penalty
      # attr_reader :recovery_attempts
      attr_reader :recovery_cost
      attr_reader :correction_cost
      attr_reader :error_count
      
      def recovery_attempts()
         puts @recovery_context.signature
         puts @previous_correction.recovery_context.signature unless @previous_correction.nil?
         return @recovery_attempts
      end
      
      def initialize( recovery_context, previous_correction, position_number, correction_penalty = 0 )
         @recovery_context    = recovery_context
         @previous_correction = previous_correction
         @position_number     = position_number                         # The sequence_number of the Position that we correct
         @correction_penalty  = correction_penalty                      # Any additional user-defined cost for using this correction
         
         #
         # Find the last correction not associated with the same original error (recovery context). 

         @previous_unassociated_correction = nil
         unless @previous_correction.nil?
            if @previous_correction.recovery_context == @recovery_context then
               @previous_unassociated_correction = @previous_correction.previous_unassociated_correction
            else
               @previous_unassociated_correction = @previous_correction
            end
         end
         
         #
         # If this is the first correction in a new recovery context, adjust the correction_penalty for proximity to 
         # the previous recovery_context.  We do this to ensure that cascading failures increase the recovery cost at 
         # each step, making it less and less likely to be chosen as the ultimate solution.  
         #
         # We use the sequence_number as a measure of distance.  This means that both REDUCE and SHIFT increase the
         # distance between failures.  This seems like a good idea, at this point, as something that causes three
         # reductions in a row is still significant for the overall parse, even though it doesn't consume any source.
         
         if @previous_correction.exists? and @previous_unassociated_correction.object_id == @previous_correction.object_id then
            distance   = @recovery_context.sequence_number - @previous_unassociated_correction.recovery_context.sequence_number
            
            if distance == 0 then
               STDERR.puts @recovery_context.signature
               STDERR.puts @previous_unassociated_correction.recovery_context.signature
               bug( "wtf?" )
            end
            
            adjustment = @previous_unassociated_correction.recovery_cost / distance
            if adjustment >= 0.25 then
               @correction_penalty += adjustment
            end
         end
         
         #
         # Calculate our recovery statistics.
            
         @recovery_attempts = 1                                           # The number of corrections (so far) on this @recovery_context
         @recovery_cost     = intrinsic_cost() + @correction_penalty      # The cost of the corrections (so far) on this @recovery_context
         @correction_cost   = @recovery_cost                              # The total cost of all corrections so far
         @error_count       = 1                                           # The number of recovery_contexts so far (ie. original errors)
         
         unless @previous_correction.nil? 
            if @previous_correction.recovery_context == @recovery_context then
               @recovery_attempts += @previous_correction.recovery_attempts
               @recovery_cost     += @previous_correction.recovery_cost
               @error_count        = @previous_correction.error_count
            else
               @error_count        = @previous_correction.error_count + 1
            end

            @correction_cost += @previous_correction.correction_cost
         end
      end
      
      
      #
      # increment_position_number()
      #  - increments the position number
      
      def increment_position_number()
         @position_number += 1
      end
      
      
      #
      # intrinsic_cost()
      #  - returns the intrinsic cost of this type of correction
      
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
      # each_correction()
      #  - calls your block once for each correction on the chain, starting with this one
      
      def each_correction( seed = nil )
         correction = self
         until correction.nil?
            if seed.nil? then
               yield( correction )
            else
               seed = yield( seed, correction )
            end
            correction = correction.previous_correction
         end
         
         return seed
      end
      
      
      #
      # each_correction_on_context()
      #  - calls your block once for each correction on this chasing that shares our recovery_context, starting with this one
      
      def each_correction_on_context( seed )
         correction = self
         until correction.nil?
            if seed.nil? then
               yield( correction )
            else
               seed = yield( seed, correction )
            end
            correction = correction.previous_correction
            break if correction.recovery_context.object_id != @recovery_context.object_id
         end
         
         return seed
      end
      
      
      #
      # each_error()
      #  - calls your block once for each unique recovery_context on the correction stack
      
      def each_error( seed )
         recovery_context = nil

         correction = self
         until correction.nil?
            if recovery_context.object_id != correction.recovery_context.object_id then
               recovery_context = correction.recovery_context
               if seed.nil? then
                  yield( recovery_context )
               else
                  seed = yield( seed, recovery_context )
               end
            end
         end
         
         return seed
      end
      
      
   end # Correction
   



end  # module Corrections
end  # module Interpreter
end  # module Rethink


require "#{$RCCLIB}/interpreter/corrections/insertion.rb"
require "#{$RCCLIB}/interpreter/corrections/replacement.rb"
require "#{$RCCLIB}/interpreter/corrections/deletion.rb"
