#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Interpreter
module PositionMarkers

 
 #============================================================================================================================
 # class StartPosition
 #  - a special Position marker that denotes the start position of the Parser

   class StartPosition < PositionMarker
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------


      def initialize( state, lexer )
         super( nil, nil, state, lexer, 0, false, nil, false, {} )
      end
      

      #
      # pop()
      #  - tells this Position it is being "popped" from the working set
      #  - returns our context Position
      
      def pop( production )
         return @context
      end
      
      
      #
      # description()
      #  - return a description of this Position (node data only)
      
      def description()
         return ""
      end


      #
      # signature()
      #  - the start position signature is special, because there is no Node to measure for extent
      
      def signature()
         return ":#{@state.number}:0"
      end
      
      
      
   end # StartPosition
   


end  # module PositionMarkers
end  # module Interpreter
end  # module Rethink


