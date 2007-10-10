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
module Markers

 
 #============================================================================================================================
 # class StartPosition
 #  - a special Position marker that denotes the start position of the Parser

   class StartPosition < GeneralPosition
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------


      def initialize( state, lexer )
         super( nil, nil, state, lexer, 0 )
      end
      
      
      #
      # error_context()
      #  - StartPosition never has one
      
      def error_context()
         return nil
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
      
      
      
   end # StartPosition
   


end  # module Markers
end  # module Interpreter
end  # module Rethink


