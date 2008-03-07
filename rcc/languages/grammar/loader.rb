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
require "#{$RCCLIB}/languages/grammar/bootstrap_grammar.rb"
require "#{$RCCLIB}/languages/grammar/model_builder.rb"

module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class Loader
 #  - loads a Grammar file from disk, using the best method available

   class Loader
      
      @@use_bootstrap_parser = !File.exists?( "#{$RCCLIB}/languages/grammar/parser/parser.rb" )
      @@bootstrap_parser     = nil
      
      def self.load_from_file( descriptor, path = nil )
         path = File.expand_path( descriptor ) if path.nil?
         
         if @@use_bootstrap_parser then
            initialize_bootstrap_parser() if @@bootstrap_parser.nil?

            grammar = nil

            File.open(path) do |file|
               grammar = Loader.new().load( file.read(), path )
            end

            return grammar
         else
            nyi( "support for pre-built parser" )
         end
         
      end


      
    #---------------------------------------------------------------------------------------------------------------------
    # Bootstrapping
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      #
      # initialize_bootstrap_parser()
      #  - loads and initializes the bootstrap parser that will be used to load Grammars
      
      def self.initialize_bootstrap_parser()
         grammar     = ModelBuilder.build( BootstrapGrammar.ast )
         parser_plan = grammar.compile_plan()
         parser_plan.compile_actions( true )
         
         @@bootstrap_parser = RCC::Scanner::Interpreter::Parser.new( parser_plan, nil, false )
      end
      
   end # Loader
   


end  # module Grammar
end  # module Languages
end  # module RCC