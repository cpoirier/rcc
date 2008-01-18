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

      def initialize( symbol_name, is_lexical )
         @symbol_name = symbol_name
         @is_lexical  = is_lexical    
         @is_slot     = false
         @slot_name   = nil
      end
      
      
      #
      # register_slot()
      #  - if you pass in a slot_name, it will be used; otherwise, one will be assigned later

      def register_slot( slot_name = nil )
         @is_slot   = true
         @slot_name = slot_name
         
         return self
      end
      
      
      
      #
      # display()
      
      def display( stream )
         if @is_lexical then
            stream.puts( "lexical symbol #{@symbol_name}")
         else
            stream.puts( "parser  symbol #{@symbol_name}")
         end
      end
      
   end # Symbol
   


end  # module Model
end  # module RCC
