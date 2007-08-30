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
 # class Correction
 #  - record of an error correction and the parse that followed it

   class Correction
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :position
      attr_reader :location
      attr_reader :inserted_token
      attr_reader :deleted_token
      attr_reader :situation
      attr_reader :context_situation
      attr_reader :context_correction
      attr_reader :quality
      attr_reader :error_depth
      
      def initialize( inserted_token, deleted_token, context_situation, context_correction )
         @position           = inserted_token.nil? ? deleted_token.rewind_position : inserted_token.rewind_position
         @location           = inserted_token.nil? ? deleted_token.sequence_number : inserted_token.sequence_number
         @inserted_token     = inserted_token
         @deleted_token      = deleted_token
         @mode               = (@inserted_token.nil? ? "DELETION" : (@deleted_token.nil? ? "INSERTION" : "SUBSTITUTION"))
         @context_situation  = context_situation
         @context_correction = context_correction
         
         STDERR.puts "MAKING CORRECTION ON #{inserted_token.nil? ? "." : inserted_token.description} #{deleted_token.nil? ? "." : deleted_token.description}"
         token_stream = context_situation.token_stream.cover( inserted_token.nil? ? [] : [inserted_token] )
         @situation   = Situation.new( token_stream, context_situation, nil, self )

         #
         # We need to provide some rating of how well the error correction is going.  This can be used
         # by the error correction system to when to defer/abandon an error correction that is doing a 
         # lot of work for little real benefit (like inserting the same token over and over again).
         #
         # For now, we'll consider the last 3 error corrections and the Token.sequence_number distance
         # between them.  We rate our chances of completing into 5 tiers:
         #   1) >= 3 errors, >= 15 tokens average distance between last 3
         #   2) >= 3 errors, >= 10 tokens average distance between last 3
         #   3) <  3 errors
         #   4) >= 3 errors, >= 5  tokens average distance between last 3
         #   5) >= 3 errors, <  4  tokens average distance between last 3
         #
         # Hopefully, this will give us a reasonable indication of how well a correction is going *recently*.
         # The parser can combine this with error count information to decide which corrections to abandon.
         
         @error_depth = 1 + (@context_correction.nil? ? 0 : @context_correction.error_depth)
         
         if @error_depth < 3 then
            @quality = 3
         else
            location_0  = @location
            location_1  = @context_correction.location
            location_2  = @context_correction.context_correction.location
                        
            distance_1  = location_0 - location_1
            distance_2  = location_1 - location_2
                        
            average     = (distance_1 + distance_2) / 2
            determinant = max( distance_1, average )

            if determinant >= 15 then
               @quality = 1
            elsif determinant >= 10 then
               @quality = 2
            elsif determinant >= 5 then
               @quality = 4
            else
               @quality = 5
            end
         end
      end
      
      
      def apply( parser, explain_indent = nil )

         unless explain_indent.nil?
            STDOUT.puts "#{explain_indent}" 
            STDOUT.puts "#{explain_indent}" 
            STDOUT.puts "#{explain_indent}===> ATTEMPTING ERROR CORRECTION BY #{@mode}; ERROR DEPTH #{@error_depth}; QUALITY #{@quality}"
         end

         result   = nil
         duration = Time.measure do
            @situation.restart( )         
            result = parser.parse( @situation, explain_indent.nil? ? nil : explain_indent + "   " )
         end

         unless explain_indent.nil?
            STDOUT.puts "#{explain_indent}" 
            STDOUT.puts "#{explain_indent}" 
            if result then
               STDOUT.puts "#{explain_indent}<=== RETURNING FROM ERROR CORRECTION WITH SOLUTION; DURATION #{duration}s"
            else
               STDOUT.puts "#{explain_indent}<=== RETURNING FROM ERROR CORRECTION WITH NO SOLUTION; DURATION #{duration}s"
            end
         end
         
         return result
      end
         
         
      #
      # accept()
      #  - marks this Correction as accepted in its parent Situation
      
      def accept()
         @context_situation.accept_correction( self )
      end
      
      
      #
      # discard()
      #  - marks this Correction as discarded in its parent Situation
      
      def discard()
         @context_situation.discard_correction( self )
      end
      
      
   end # Correction
   


end  # module Interpreter
end  # module Rethink
