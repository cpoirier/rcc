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
      attr_reader :active_from_position
      attr_reader :active_to_position
      attr_reader :recovery_attempts
      attr_reader :correction_cost
      attr_reader :error_count
      
      def initialize( recovery_context, previous_correction, position_number, correction_penalty = 0 )
         @recovery_context     = recovery_context
         @previous_correction  = previous_correction
         @active_from_position = position_number
         @active_to_position   = position_number
         @correction_penalty   = correction_penalty                      # Any additional user-defined cost for using this correction
         
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
         # Calculate our recovery statistics.  Some are dynamic and will be calculated on demand.
            
         @recovery_attempts = 1                                           # The number of corrections (so far) on this @recovery_context
         @error_count       = 1                                           # The number of recovery_contexts so far (ie. original errors)
         
         unless @previous_correction.nil? 
            if @previous_correction.recovery_context == @recovery_context then
               @recovery_attempts += @previous_correction.recovery_attempts
               @error_count        = @previous_correction.error_count
            else
               @error_count        = @previous_correction.error_count + 1
            end
         end
      end
      
      
      #
      # correction_penalty()
      #  - returns the current total correction penalty for this correction
      
      def correction_penalty()
         
         #
         # If this is the first correction in a new recovery context, adjust the correction_penalty for proximity to 
         # the previous recovery_context.  We do this to ensure that cascading failures increase the recovery cost at 
         # each step, making it less and less likely to be chosen as the ultimate solution.  
         #
         # We use the sequence_number as a measure of distance.  This means that both REDUCE and SHIFT increase the
         # distance between failures.  This seems like a good idea, at this point, as something that causes three
         # reductions in a row is still significant for the overall parse, even though it doesn't consume any source.
         
         if @previous_correction.exists? and @previous_unassociated_correction.object_id == @previous_correction.object_id then
            distance = @recovery_context.sequence_number - @previous_unassociated_correction.active_to_position
            adjustment = @previous_unassociated_correction.recovery_cost / distance
            return @correction_penalty + (adjustment >= 0.25 ? adjustment : 0)
         else
            return @correction_penalty
         end
      end
      
      
      #
      # recovery_cost()
      #  - returns a number indicating how much this recovery cost, in relative terms
      
      def recovery_cost()
         cost = intrinsic_cost() + correction_penalty()
         
         unless @previous_correction.nil?
            cost += @previous_correction.recovery_cost
         end 
         
         return cost
      end
      
      
      #
      # correction_cost()
      #  - returns a number indicating how much all recoveries cost
      
      def correction_cost()
         if @previous_correction.nil? then
            return recovery_cost()
         else
            return recovery_cost() + @previous_correction.correction_cost
         end
      end
      
      
      #
      # expand_scope()
      #  - expands the scope of this correction by one position
      
      def expand_scope( to_position )
         @active_to_position = to_position
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
