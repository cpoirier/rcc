#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class Symbol
 #  - the Plan's idea of a Symbol; it's analogous to the Model Symbol, but simpler

   class Symbol
      
      @@end_of_input_symbol = nil
      
      def self.end_of_input()
         @@end_of_input_symbol = new( nil, true ) if @@end_of_input_symbol.nil?
         return @@end_of_input_symbol
      end
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      
      def initialize( name, terminal_indicator )
         @name     = name
         @terminal = terminal_indicator
      end
      
      def terminal?()
         @terminal
      end
      
      def non_terminal?()
         !@terminal
      end
      
      def hash()
         return @name.hash
      end
      
      def eql?( rhs )
         return false unless rhs.is_a?(Plan::Symbol)
         return @name == rhs.name
      end
      
      def to_s()
         return "$"        if name.nil?
         return "#{@name}" if name.is_a?(::Symbol)
         return "'#{@name.gsub("\\", "\\\\").gsub("\n", "\\n").gsub("'", "''")}'"
      end
      
      
   end # Symbol
   


   


end  # module Plan
end  # module Rethink
