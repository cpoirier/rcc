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
require "#{$RCCLIB}/plan/master_plan.rb"


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
         grammar.system = self
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------
    

      #
      # compile_plan()
      #  - returns a Plan::MasterPlan built to produce parsers for each of the specified start_rules
      #  - if you pass no start_rules, then the start rule of the first grammar will be use
      #  - start_rules must be RuleReference objects
      
      def compile_plan( start_rules = [] )
         if start_rules.empty? then
            start_rules << @grammars[0].start_rule
         end
         
         return Plan::MasterPlan.build( self, start_rules )
      end


   end # System



   


end  # module Model
end  # module RCC
