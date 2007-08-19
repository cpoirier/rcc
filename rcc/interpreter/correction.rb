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
      
      def initialize( inserted_token, deleted_token, context_situation )
         @position       = inserted_token.nil? ? deleted_token.start_position : inserted_token.start_position
         @inserted_token = inserted_token
         @deleted_token  = deleted_token
         @mode           = (@inserted_token.nil? ? "DELETION" : (@deleted_token.nil? ? "INSERTION" : "SUBSTITUTION"))
         
         token_stream = context_situation.token_stream.cover( inserted_token.nil? ? [] : [inserted_token] )
         @situation   = Situation.new( token_stream, context_situation )
      end
      
      
      def apply( parser, explain = false, indent = "" )

         if explain then
            STDOUT.puts "#{indent}" 
            STDOUT.puts "#{indent}" 
            STDOUT.puts "#{indent}===> ATTEMPTING ERROR CORRECTION BY #{@mode}"

         end
         
         result = parser.parse( @situation, explain, indent + "   " )

         if explain then
            STDOUT.puts "#{indent}" 
            STDOUT.puts "#{indent}" 
            if result then
               STDOUT.puts "#{indent}<=== RETURNING FROM ERROR CORRECTION WITH SOLUTION"
            else
               STDOUT.puts "#{indent}<=== RETURNING FROM ERROR CORRECTION WITH NO SOLUTION"
            end
         end
         
         return result
      end
      
      
      
   end # Correction
   


end  # module Interpreter
end  # module Rethink
