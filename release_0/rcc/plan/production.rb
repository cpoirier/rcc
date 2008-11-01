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
require "#{$RCCLIB}/plan/symbol.rb"
require "#{$RCCLIB}/scanner/artifacts/name.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class Production
 #  - a base class for things that describe how to produce Nodes during parsing

   class Production
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :number
      attr_reader   :name
      attr_reader   :symbols
      attr_accessor :master_plan

      def initialize( number, name, symbols, master_plan = nil )
         type_check( name, Scanner::Artifacts::Name )
         
         @number        = number
         @name          = name
         @symbols       = symbols
         @master_plan   = master_plan
      end
      
      def syntactic?()
         return false
      end
      
      def lexical?()
         return !syntactic?
      end
      
      alias rule_name name
      
      def signature()
         return @name.signature
      end
      
      def description( elide_grammar = nil )
         return @name.description( elide_grammar )
      end      

      
      def length()
         return @symbols.length
      end
      
      
      def to_s()
         return "#{@name.description} => #{@symbols.join(" ")}"
      end

      def ==( rhs )
         return @number == rhs.number
      end
      
      
      def display( stream = $stdout )
         stream.puts "#{@name} =>"
         stream.indent do
            length().times do |i|
               stream.puts( @symbols[i].description )
            end
         end
      end
      
      
   end # Production
   





end  # module Plan
end  # module RCC


require "#{$RCCLIB}/plan/syntax_production.rb"
require "#{$RCCLIB}/plan/token_production.rb"

