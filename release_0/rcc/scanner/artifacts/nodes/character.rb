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
require "#{$RCCLIB}/scanner/artifacts/node.rb"

module RCC
module Scanner
module Artifacts
module Nodes
   

 
 #============================================================================================================================
 # class Character
 #  - a single Character read from a source file

   class Character < Node
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :token_count               # The number of Tokens in this and all sub CSNs
      attr_reader :original_error_position   # The stream position at which the last original (non-cascade) error occurred
      attr_reader :line_number
      attr_reader :column_number
      attr_reader :source
      attr_reader :position 
      
      alias start_position position
      
      def initialize( code, position, source ) 
         code = source[position] if code.nil?
         super( Name.new(code) )
         
         @line_number   = source.line_number(position)
         @column_number = source.column_number(position)
         @position      = position
         @source        = source
      end
      
      def character()
         return @type.name
      end
      
      def description()
         return @type.to_s
      end
      
      def follow_position()
         return @position + 1
      end
      
      def character?()
         return true
      end
            
      def first_token()
         return nil
      end

      def last_token()
         return nil
      end
      






    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      
   end # Node
   


end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC

