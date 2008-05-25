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
module Elements

 
 #============================================================================================================================
 # class Pattern
 #  - describes a lexical string that can be produced by the Parser

   class Pattern
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :name
      attr_reader :master_form

      def initialize( name, master_form )
         @name        = name
         @master_form = master_form
      end
      
      def display( stream = $stdout )
         stream.puts "string pattern #{@name}:"
         stream.indent do
            @master_form.display( stream )
         end
      end
      
      def tokenizeable?()
         return true
      end
      
      
   end # Pattern
   






 #============================================================================================================================
 # class Subpattern
 #  - represents a subpattern that has been factored out for repeating
 
   class Subpattern < Pattern
      
      Optional = Util::ExpressionForms::Optional
      Sequence = Util::ExpressionForms::Sequence
            
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :rule_form
      attr_reader :singular_form
      
      def initialize( name, singular_form )
         @singular_form = singular_form
         
         tree_side = Markers::Reference.new( name )
         rule_form = Sequence.new( Optional.new(tree_side), @singular_form )
         super( name, rule_form )
      end
      
      def tokenizeable?()
         return false
      end

   end # Subpattern
   
   
   
 
end  # module Elements
end  # module Model
end  # module RCC
