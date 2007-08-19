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
require "#{$RCCLIB}/plan/sequence_set.rb"
require "#{$RCCLIB}/plan/production.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class ProductionSet
 #  - holds a related (in whatever way) set of Productions and provides useful services there-upon

   class ProductionSet < SequenceSet
      
      #
      # ::start_set
      
      def self.start_set( start_rule_name )
         return new( nil, [Production.start_production(start_rule_name)] )
      end
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      attr_reader :productions
      
      def initialize( name, productions = [] )
         super( productions.collect{|production| production.symbols} )
         @name            = name
         @productions     = productions
      end

      def <<( production )
         super( production.symbols )
         @productions << production
      end
      
      






      
      
   end # ProductionSet
   


end  # module Plan
end  # module Rethink
