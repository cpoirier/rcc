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
module Plan

 
 #============================================================================================================================
 # class SymbolGroup
 #  - manages a series of Symbols in a Group 

   class SymbolGroup
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbols
      
      def initialize( symbols = [] )
         @symbols   = symbols
         @signature = nil
      end
      
      
      def each_symbol()
         @symbols.each do |symbol|
            yield( symbol )
         end
      end
      
      
      def <<( symbol )
         @symbols << symbol
      end
      
      
      def signature()
         @signature = @symbols.collect{|symbol| symbol.signature}.join("|") if @signature.nil?
         return @signature
      end      
      
      
      def hash()
         return signature().hash
      end
      
      
      def eql?( rhs )
         return false unless rhs.is_a?(Plan::Symbol)
         return signature() == rhs.signature
      end
      
      
   end # SymbolGroup
   


   


end  # module Plan
end  # module RCC
