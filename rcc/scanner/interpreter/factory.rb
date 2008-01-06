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
      attr_accessor :explain_indent
      attr_reader   :parser_plan
      
      def initialize( grammar_or_parser_plan, recovery_limit = 3, explain_indent = nil )
         if grammar_or_parser_plan.is_an?(RCC::Model::Grammar) then
            grammar = grammar_or_parser_plan
            @parser_plan = grammar.compile_plan().compile_actions(true)
         else
            @parser_plan = grammar_or_parser_plan
         end
         
         @recovery_limit = 3
         @explain_indent = explain_indent
      end
      
      
      #
      # parse()
      #  - parses a file using machinery produced by this Factory
      
      def parse( descriptor, file = nil )
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
         solution = parser.parse( @recovery_limit, @explain_indent )
            
         return solution
      end

      
   end # Factory
   





end  # module Interpreter
end  # module Scanner
end  # module RCC
