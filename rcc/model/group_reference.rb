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
 
 
 #============================================================================================================================
 # class GroupReference
 #  - represents a group reference in a rule

   class GroupReference < Util::ExpressionForms::BranchPoint
      include SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :group_name
      attr_reader :group
      alias symbol_name group_name
      
      def initialize( group_name, group )
         super( *group.branches.collect{|element| element.clone} )
         @group_name = group_name
         @group      = group
      end
      
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info() do 
            stream.puts( "parse(#{@branches.collect{|s| s.symbol_name}.join("|")})" )
         end
      end
      
      
   end # GroupReference
   


end  # module Model
end  # module RCC
