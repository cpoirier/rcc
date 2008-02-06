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
module Model

 
 #============================================================================================================================
 # class Symbol
 #  - represents a symbol in a rule, to be produced by the lexer (terminal) or by the parser (non-terminal)

   class Symbol
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :symbol_name
      attr_reader :slot_name
      
      def initialize( symbol_name, is_lexical )
         @symbol_name = symbol_name
         @is_lexical  = is_lexical    
         @slot_name   = nil
      end
      
      
      #
      # slot_name=()

      def slot_name=( slot_name )
         @slot_name = slot_name
         return self
      end
      
      
      
      #
      # display()
      
      def display( stream )
         if @is_lexical then
            stream.puts( "lex(#{@symbol_name})#{@slot_name.exists? ? " as :#{@slot_name}" : ""}")
         else
            stream.puts( "parse(#{@symbol_name})#{@slot_name.exists? ? " as :#{@slot_name}" : ""}")
         end
      end
      
   end # Symbol
   


end  # module Model
end  # module RCC
