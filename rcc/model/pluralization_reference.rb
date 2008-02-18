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
require "#{$RCCLIB}/util/expression_forms/repeater.rb"

module RCC
module Model
 
 
 #============================================================================================================================
 # class PluralizationReference
 #  - represents a pluralization reference in a rule

   class PluralizationReference < Util::ExpressionForms::ExpressionForm
      include SlotInfo
      Optional = Util::ExpressionForms::Optional
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :pluralization
      attr_reader :pluralization_name
      alias symbol_name pluralization_name
      
      def initialize( pluralization, optional = false )
         @pluralization_name = pluralization.name
         @pluralization      = pluralization
         @optional           = optional
         @expression         = RuleReference.new( @pluralization_name )
         @expression         = Optional.new( @expression ) if optional
      end      
      
      
      #
      # display()
      
      def display( stream = $stdout )
         display_slot_info() do 
            @expression.display( stream )
         end
      end
      
      
      #
      # each_element()
      
      def each_element()
         yield( @expression )
      end
      
      
      #
      # element_count()
      
      def element_count()
         return 1
      end
      
      
      #
      # 
      
      
      
   end # PluralizationReference
   


end  # module Model
end  # module RCC
