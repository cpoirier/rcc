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
      attr_reader :inserted_token
      attr_reader :deleted_token
      attr_reader :situation
      attr_reader :context_situation
      
      def initialize( inserted_token, deleted_token, context_situation )
         @position          = inserted_token.nil? ? deleted_token.start_position : inserted_token.start_position
         @inserted_token    = inserted_token
         @deleted_token     = deleted_token
         @mode              = (@inserted_token.nil? ? "DELETION" : (@deleted_token.nil? ? "INSERTION" : "SUBSTITUTION"))
         @context_situation = context_situation
         
         token_stream = context_situation.token_stream.cover( inserted_token.nil? ? [] : [inserted_token] )
         @situation   = Situation.new( token_stream, context_situation )
      end
      
      def apply( parser, explain_indent = nil )

         unless explain_indent.nil?
            STDOUT.puts "#{explain_indent}" 
            STDOUT.puts "#{explain_indent}" 
            STDOUT.puts "#{explain_indent}===> ATTEMPTING ERROR CORRECTION BY #{@mode}"

         end
         
         @situation.restart( )         
         result = parser.parse( @situation, explain_indent.nil? ? nil : explain_indent + "   " )

         unless explain_indent.nil?
            STDOUT.puts "#{explain_indent}" 
            STDOUT.puts "#{explain_indent}" 
            if result then
               STDOUT.puts "#{explain_indent}<=== RETURNING FROM ERROR CORRECTION WITH SOLUTION"
            else
               STDOUT.puts "#{explain_indent}<=== RETURNING FROM ERROR CORRECTION WITH NO SOLUTION"
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
