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

      attr_reader :name
      attr_writer :recoverable
      
      def initialize( name, refers_to_token )
         @name            = name
         @refers_to_token = refers_to_token
         @recoverable     = false
      end
      
      def refers_to_token?()
         @refers_to_token
      end
      
      def refers_to_production?()
         !@refers_to_token
      end
      
      def recoverable?()
         @recoverable
      end
      
      def signature( elide_grammar = nil )
         if elide_grammar.exists? and not @name.literal? and elide_grammar == @name.grammar then
            return @name.name
         else
            return @name.signature
         end
      end      
      
      def hash()
         return signature().hash
      end
      
      # def eql?( rhs )
      #    return false unless rhs.is_a?(Plan::Symbol)
      #    return signature() == rhs.signature
      # end
      # 
      # def to_s()
      #    return (@refers_to_token ? "lex" : "parse") + ":" + (@symbol_name.nil? ? "$" : (@grammar_name + "." + @symbol_name))
      # end
      # 
      # def self.describe( name )
      #    return "$" if name.nil?
      #    return name.to_s
      # end
      
      
   end # Symbol
   


   


end  # module Plan
end  # module RCC
