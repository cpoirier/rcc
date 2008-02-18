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
require "#{$RCCLIB}/util/expression_forms/repeater.rb"
require "#{$RCCLIB}/model/model.rb"


module RCC
module Model

 
 #============================================================================================================================
 # class Pluralization
 #  - represents a subrule that has been factor out for repeating
 
   class Pluralization < Rule
      
      Optional = Util::ExpressionForms::Optional
      Sequence = Util::ExpressionForms::Sequence
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :rule_form
      attr_reader :singular
      
      def initialize( rule_name, singular_form )
         @singular_form = singular_form
         
         rule_name = "_pluralizer_#{object_id}" if rule_name.nil?
         tree_side = RuleReference.new( rule_name )
         rule_form = Sequence.new( Optional.new(tree_side), @singular_form )
         super( rule_name, rule_form )

         # BUG: this prevents effectively slotless Pluralizations from being discarded internally, and maybe should be fixed
         tree_side.set_slot_name( self, "_tree" )
      end
      
      
      def reference( optional = true )
         return PluralizationReference.new( self, optional )
      end
      
      
      def has_slots?()
         return @slots.length > 1
      end
      
      
   end # Pluralizer
   


end  # module Model
end  # module RCC
