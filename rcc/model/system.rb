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
require "#{$RCCLIB}/util/ordered_hash.rb"
require "#{$RCCLIB}/model/grammar.rb"


module RCC
module Model

 
 #============================================================================================================================
 # class System
 #  - a single system of Grammars

   class System
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :grammars
      
      def initialize()
         @grammars = Util::OrderedHash.new()    # name => Grammar
      end

      
      def add_grammar( grammar )
         type_check( grammar, Grammar )
         assert( !@grammars.member?(grammar.name), "name [#{grammar.name}] is already in use" )
         
         @grammars[grammar.name] = grammar
      end

      
   end # System



   


end  # module Model
end  # module RCC
