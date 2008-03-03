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
module Elements

 
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
      
      def initialize( name, singular_form )
         @singular_form = singular_form
         
         tree_side = References::RuleReference.new( name )
         rule_form = Sequence.new( Optional.new(tree_side), @singular_form )
         super( name, rule_form )

         # BUG: this prevents effectively slotless Pluralizations from being discarded internally, and maybe should be fixed
         tree_side.set_slot_name( self, "_tree" )
      end
      
      
      def reference( optional = true )
         return References::PluralizationReference.new( self, optional )
      end
      
      
      def has_slots?()
         return @slots.length > 1
      end
      
      
   end # Pluralizer
   

end  # module Elements
end  # module Model
end  # module RCC
