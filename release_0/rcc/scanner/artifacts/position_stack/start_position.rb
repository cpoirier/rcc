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

module RCC
module Scanner
module Artifacts
module PositionStack

 
 #============================================================================================================================
 # class StartPosition
 #  - a special Position marker that denotes the start position of the Parser

   class StartPosition < PositionMarker
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------


      def initialize( state, source )
         super( nil, nil, state, source, 0 )
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
      
      def description( include_determinant = false )
         if include_determinant then
            return " | #{determinant().description}"
         else
            return ""
         end
      end


      def start_position?
         return true
      end
      
   end # StartPosition
   


end  # module PositionStack
end  # module Artifacts
end  # module Scanner
end  # module RCC


