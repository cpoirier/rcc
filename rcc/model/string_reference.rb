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
 # class StringReference
 #  - represents a string reference in a rule

   class StringReference
      include SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :string_name
      alias symbol_name string_name
      
      def initialize( string_name )
         @string_name = string_name
      end
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info() do 
            stream.puts "lex(#{@string_name})"
         end
      end
      
      
   end # StringReference
   


end  # module Model
end  # module RCC
