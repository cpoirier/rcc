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
require "#{$RCCLIB}/model/model.rb"

module RCC
module Model
module Markers
    
 
 #============================================================================================================================
 # class RuleReference
 #  - represents a rule reference in a rule

   class RuleReference
      include Model::Elements::SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :rule_name
      alias symbol_name rule_name
      alias name rule_name
      
      def initialize( rule_name )
         @rule_name = rule_name
      end
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info(stream) do 
            stream.puts "parse(#{@rule_name})"
         end
      end
      
      
      def hash()
         return @rule_name.hash
      end
      
      def ==( rhs )
         return @rule_name == rhs.symbol_name
      end
      
      alias eql? ==
      
      
   end # RuleReference
   


end  # module Markers
end  # module Model
end  # module RCC
