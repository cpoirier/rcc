#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/scanner/artifacts/source.rb"
require "#{$RCCLIB}/scanner/interpreter/lexer.rb"
require "#{$RCCLIB}/scanner/interpreter/parser.rb"


module RCC
module Scanner
module Interpreter

 
 #============================================================================================================================
 # class Factory
 #  - a factory to produce the correct equipment, given a few starting points

   class Factory
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_accessor :recovery_limit
      attr_reader   :parser_plan
      
      def initialize( parser_plan, recovery_limit = 3 )
         @parser_plan    = parser_plan
         @recovery_limit = 3
      end
      
      
      #
      # parse()
      #  - parses a file using machinery produced by this Factory
      
      def parse( descriptor, explain = false, file = nil )
         source = nil
         
         #
         # Product a Source to wrap the file.
         
         if file.nil? then
            File.open(descriptor) do |file|
               source = Scanner::Artifacts::Source.new( file.read, descriptor )
            end
         else
            source = Scanner::Artifacts::Source.new( file.read, descriptor )
         end
         
         
         #
         # Create a Lexer, a Parser, and go.
         
         lexer    = RCC::Scanner::Interpreter::Lexer.new( source )
         parser   = RCC::Scanner::Interpreter::Parser.new( @parser_plan, lexer )
         solution = parser.parse( @recovery_limit, explain )
            
         return solution
      end

      
   end # Factory
   





end  # module Interpreter
end  # module Scanner
end  # module RCC
