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
module References
 
 
 #============================================================================================================================
 # class PluralizationReference
 #  - represents a pluralization reference in a rule

   class PluralizationReference < Util::ExpressionForms::ExpressionForm
      include Model::Elements::SlotInfo
      
      ExpressionForm = Util::ExpressionForms::ExpressionForm
      Optional       = Util::ExpressionForms::Optional
      BranchPoint    = Util::ExpressionForms::BranchPoint
      Sequence       = Util::ExpressionForms::Sequence
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :pluralization
      
      def pluralization_name() ; return @pluralization.name ; end
      alias symbol_name pluralization_name
      
      def initialize( pluralization, optional = false )
         @pluralization = pluralization
         @optional      = optional
         @expression    = RuleReference.new(@pluralization.name)
         @expression    = Optional.new( @expression ) if optional
      end      
      
      
      #
      # paths()
      
      def paths()
         if @expression.is_an?(ExpressionForm) then
            return @expression.paths()
         else
            return BranchPoint.new(Sequence.new(@expression))
         end
      end


      
      #
      # display()
      
      def display( stream = $stdout )
         display_slot_info(stream) do 
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
      
      
      
   end # PluralizationReference
   


end  # module References
end  # module Model
end  # module RCC