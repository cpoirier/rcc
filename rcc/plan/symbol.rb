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

      attr_reader :grammar_name
      attr_reader :symbol_name
      
      def initialize( grammar_name, symbol_name, names_token )
         @grammar_name = grammar_name
         @symbol_name  = symbol_name
         @names_token  = names_token
      end
      
      def names_token?()
         @names_token
      end
      
      def names_production?()
         !@names_token
      end
      
      def hash()
         return @name.hash
      end
      
      def eql?( rhs )
         return false unless rhs.is_a?(Plan::Symbol)
         return @name == rhs.name
      end
      
      def to_s()
         return (@names_token ? "lex" : "parse") + " " + (@symbol_name.nil? ? "$" : (@grammar_name + ":" + @symbol_name))
      end
      
      # def self.describe( name )
      #    return "$" if name.nil?
      #    return name.to_s
      # end
      
      
   end # Symbol
   


   


end  # module Plan
end  # module RCC
