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
 # class GatewayMarker
 #  - represents a gateway expression in a rule
 #  - despite the inclusion of SlotInfo, GatewayMarker cannot be slotted!

   class GatewayMarker
      include Model::Elements::SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbol_name
      
      def initialize( symbol_name )
         @symbol_name = symbol_name
      end
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info(stream) do 
            stream.puts "refuse(#{@string_name})"
         end
      end
      
      
   end # GatewayMarker
   


end  # module Markers
end  # module Model
end  # module RCC
