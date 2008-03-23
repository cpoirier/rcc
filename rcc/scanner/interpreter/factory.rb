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
      
      def parse( descriptor, estream = nil, file = nil )
         return build_parser( descriptor, file ).parse( @recovery_limit, estream )
      end
      
      
      #
      # open_source()
      #  - returns a Source around your input
      
      def open_source( descriptor, file = nil )
         return descriptor if descriptor.is_a?(RCC::Scanner::Artifacts::Source)
         return RCC::Scanner::Artifacts::Source.open( descriptor, file )
      end
      
      
      #
      # build_lexer()
      #  - returns a Lexer around your input
      
      def build_lexer( descriptor, file = nil )
         return RCC::Scanner::Interpreter::Lexer.new( open_source(descriptor, file) )
      end
      
      
      #
      # build_parser()
      #  - returns a new Parser on your Lexer
      
      def build_parser( descriptor, file = nil )
         return RCC::Scanner::Interpreter::Parser.new( @parser_plan, build_lexer(descriptor, file) )
      end
      
      
   end # Factory
   





end  # module Interpreter
end  # module Scanner
end  # module RCC
