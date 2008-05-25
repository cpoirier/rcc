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
require "#{$RCCLIB}/plan/sequence_set.rb"
require "#{$RCCLIB}/plan/production.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class ProductionSet
 #  - holds a related (in whatever way) set of Productions and provides useful services thereupon

   class ProductionSet < SequenceSet
      

    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :productions
      
      def initialize( productions = [] )
         super( productions.collect{|production| production.symbols} )
         @productions = productions
      end

      def <<( production )
         super( production.symbols )
         @productions << production
      end
      
      
      
   end # ProductionSet
   


end  # module Plan
end  # module RCC
