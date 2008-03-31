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
 # class StringReference
 #  - represents a string reference in a rule

   class StringReference
      include Model::Elements::SlotInfo
      
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
         display_slot_info(stream) do 
            stream.puts "lex(#{@string_name})"
         end
      end
      
      
      
      def hash()
         return @string_name.hash
      end
      
      def ==( rhs )
         return @string_name == rhs.symbol_name
      end
      
      alias eql? ==
      
      
      
   end # StringReference
   


end  # module Markers
end  # module Model
end  # module RCC
