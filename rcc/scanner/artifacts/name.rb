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
module Scanner
module Artifacts
   

 
 #============================================================================================================================
 # class Name
 #  - a class for names used and produced by an RCC lexer/parser system
 #  - names can be literal or symbolic; if symbolic, a grammar name must be included

   class Name
      
      
      def self.end_of_file_type()
         return @@end_of_file_type         
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :grammar
      attr_reader :name
      attr_reader :signature
      
      def initialize( name, grammar = nil )
         type_check( name, String, true )
         @grammar   = grammar
         @name      = name
         @signature = name.nil? ? "$" : (grammar.nil? ? "\"#{@name.escape}\"" : "#{@grammar}.#{@name}")
      end
      
      
      def pluralize()
         return @name.pluralize()
      end
      
      
      def eof?()
         return @name.nil?
      end

      
      def literal?
         return @grammar.nil?
      end


      def to_s()
         return @signature
      end
      
      
      def ==( rhs )
         if rhs.is_a?(String) then
            return (@name == rhs || @signature == rhs)
         else
            return @signature == rhs.signature
         end
      end
      
      alias === ==
      alias eql? ==
      
      def hash()
         return @signuature.hash
      end
      

      @@end_of_file_type = self.new( nil, nil )
      
   end # Node
   


end  # module Artifacts
end  # module Scanner
end  # module RCC

