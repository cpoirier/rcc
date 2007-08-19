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
require "#{$RCCLIB}/model/form_elements/symbol.rb"

module RCC
module Model

 
 #============================================================================================================================
 # class Phrase
 #  - a series of Symbols
 
   class Phrase
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbols
      
      def initialize( symbols = [] )
         @symbols = symbols.is_a?(Array) ? symbols : [ symbols ]
      end
      
      def []( index )
         return @symbols[index]
      end
      
      
      #
      # hash()
      
      def hash()
         return @symbols[0].hash
      end
      
      
      #
      # eql?()

      def eql?( rhs )
         return false unless @symbols.length == rhs.symbols.length
         @symbols.length.times do |i|
            return false unless @symbols[i] == rhs.symbols[i]
         end
         
         return true
      end


      #
      # <<()
      #  - appends a Symbol to the Phrase
      
      def <<( symbol )
         type_check( symbol, Model::Symbol )
         @symbols << symbol
      end

      
      #
      # +()
      #  - returns a new Phrase by adding the symbols in this Phrase with those of that supplied
      
      def +( rhs )
         return Phrase.new( @symbols + rhs.symbols )
      end
      
      
      #
      # ==()
      #  - returns true if this Phrase is equal to the one you supplied
      
      def ==( rhs )
         return @symbols == rhs.symbols
      end
      
      
      #
      # length()
      #  - returns the number of symbols in this Phrase
      
      def length()
         return @symbols.length
      end
      
      
      #
      # empty?()
      #  - returns true if the Phrase is empty
      
      def empty?()
         return @symbols.empty?
      end


      #
      # slice()
      #  - returns a Phrase with some subset of this Phrase
      #  - parameters follow Array.slice()
       
      def slice(*parameters)
         return Phrase.new( @symbols.slice(*parameters) )
      end
      
      
      #
      # each()
      #  - calls your block once for of the Symbols in this Phrase
      
      def each()
         @symbols.each do |symbol|
            yield( symbol )
         end
      end
      






    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         @symbols.join(" ")
      end

      def display( stream, indent = "" )
         stream << indent << "Phrase\n"
         @symbols.each do |symbol|
           symbol.display( stream, indent + "   " )
         end
      end
      
   end # Phrase
   







end  # module Model
end  # module Rethink
