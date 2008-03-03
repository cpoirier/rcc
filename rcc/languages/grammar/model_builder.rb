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
require "#{$RCCLIB}/languages/grammar/grammar_builder.rb"
require "#{$RCCLIB}/model/model.rb"


module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class ModelBuilder
 #  - builds an RCC::Model::System from an AST parsed from a grammar source file

   class ModelBuilder
      
      #
      # ::build()
      #  - given an AST of a grammar source file, returns a Model::System or an error report
      
      def self.build( ast )
         builder = new()
         return builder.build_model( ast )
      end
      
      Node  = RCC::Scanner::Artifacts::Node
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @builders = Util::OrderedHash.new()    # name => GrammarBuilder
      end



      #
      # build_model()
      #  - given a AST of a grammar source file, returns a Model::Grammar or an error report
      
      def build_model( system_spec )
         assert( system_spec.type == :system_spec, "Um, perhaps you meant to pass a system_spec AST?" )
         
         #
         # Pass 1: load up all the GrammarBuilders so that all names can be verified.
         
         system_spec.grammar_specs.each do |grammar_spec|
            if @builders.member?(grammar_spec.name.text) then
               nyi( "error handling for duplicate grammar name" )
            else
               @builders[grammar_spec.name.text] = GrammarBuilder.new( grammar_spec, self )
            end
         end
         
         
         #
         # Pass 2: build the Model and return it.
         
         @system = Model::System.new()
         @builders.each do |builder|
            @system.add_grammar( builder.build_model() )
         end
         
         return @system
      end
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
