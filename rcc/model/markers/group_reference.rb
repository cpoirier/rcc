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
 # class GroupReference
 #  - represents a group reference in a rule

   class GroupReference
      include Model::Elements::SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :group
      
      def group_name() ; return @group.name ; end
      alias symbol_name group_name
      
      def initialize( group )
         assert( group.name.exists?, "you can't use an anonymous group for a reference" )
         @group = group
      end
      
      
      
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info(stream) do 
            stream.puts( "parse(#{@group.name})" )
         end
      end
      
      
   end # GroupReference
   


end  # module Markers
end  # module Model
end  # module RCC
