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

 
 #============================================================================================================================
 # class CSN
 #  - a Node in a Concrete Syntax Tree produced by the Interpreter

   class CSN
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :root_symbol         # The Symbol this CSN represents
      attr_reader :component_symbols   # The Symbols that comprise it
      attr_reader :token_count         # The number of Tokens in this and all sub CSNs
      
      alias :symbol :root_symbol
      alias :type   :root_symbol
      
      def initialize( root_symbol, component_symbols )
         @root_symbol       = root_symbol
         @component_symbols = component_symbols
         @token_count       = component_symbols.inject(0) {|sum, symbol| symbol.token_count }
         
         @tainted = false
         @component_symbols.each do |symbol|
            if symbol.tainted? then
               @tainted = true
               @last_correction = symbol.last_correction
            end
         end
      end
      
      def first_token
         return @component_symbols[0].first_token
      end
      
      def last_token
         return @component_symbols[-1].last_token
      end
      
      def follow_position()
         return last_token().follow_position()
      end
      
      def description()
         return "#{@root_symbol}"
      end
      
      def terminal?()
         return false
      end      
      
      
      def display( stream, indent = "" )
         stream << indent << "#{@root_symbol} =>" << "\n"
         
         child_indent = indent + "   "
         @component_symbols.each do |symbol|
            symbol.display( stream, child_indent )
         end
      end
      




    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # tainted?
      #  - returns true if this CSN carries Correction taint
      
      def tainted?()
         return @tainted
      end
      
      
      #
      # untaint()
      #  - clears the taint from this CSN (any Correction is still linked)
      
      def untaint()
         @tainted = false
      end
      
      
      #
      # last_correction()
      #  - returns the last Correction object associated with this CSN
      
      def last_correction()
         return nil if !defined(@correction)
         return @correction 
      end
    
      
   end # CSN
   


end  # module Interpreter
end  # module Rethink
