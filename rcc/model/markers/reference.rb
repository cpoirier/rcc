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
 # class Reference
 #  - represents a reference in a rule

   class Reference
      include Model::Elements::SlotInfo
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbol_name
      alias name symbol_name
      
      def initialize( symbol_name )
         type_check( symbol_name, Scanner::Artifacts::Name )
         @symbol_name = symbol_name
      end
      
      
      #
      # resolve()
      #  - returns the object this Reference refers to
      
      def resolve( against )
         return against.resolve(symbol_name)
      end
      
      
      #
      # display()
      
      def display( stream )
         display_slot_info(stream) do 
            stream.puts "#{@symbol_name}"
         end
      end
      
      
      def hash()
         return @symbol_name.hash
      end
      
      def ==( rhs )
         return @symbol_name == rhs.symbol_name
      end
      
      alias eql? ==
      
      
   end # Reference
   


end  # module Markers
end  # module Model
end  # module RCC
