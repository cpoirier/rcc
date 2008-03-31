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
      
      def self.any_type()
         return @@any_type
      end
      
      
      def self.in_grammar( grammar_name )
         with_context_variables( :grammar_name => grammar_name ) { yield() }
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :grammar
      attr_reader   :name
      attr_reader   :signature
      attr_accessor :source_token
      
      def initialize( name, grammar = nil, source_token = nil )
         @grammar      = grammar
         @name         = name
         @source_token = source_token
         
         case name
         when nil
            @signature = "$"
         when true
            @signature = "*"
         else
            @signature = grammar.nil? ? "\"#{@name.escape}\"" : "#{@grammar}.#{@name}"
         end
      end
      
      
      def description( context = nil )
         if @name.nil? then
            return "$"
         elsif @name == true then
            return "*"
         else
            context = context_variable(:grammar_name) if context.nil?
            if context and context == @grammar then
               return @name
            else
               return @signature
            end
         end
      end

      
      def pluralize()
         return @name.pluralize()
      end
      
      
      def eof?()
         return @name.nil?
      end
      
      def wildcard?()
         return @name == true
      end

      
      def literal?
         return @grammar.nil?
      end


      
      def ==( rhs )
         if rhs.is_a?(String) then
            return (@name == rhs || @signature == rhs)
         else
            return @signature == rhs.signature
         end
      end
      
      def <=>( rhs )
         self.signature() <=> rhs.signature()
      end
      
      def hash()
         return @signature.hash
      end
      
      alias === ==
      alias eql? ==
      alias to_s description
      
      
      

      @@end_of_file_type = self.new( nil, nil )
      @@any_type         = self.new( true, nil )
      
   end # Node
   


end  # module Artifacts
end  # module Scanner
end  # module RCC

