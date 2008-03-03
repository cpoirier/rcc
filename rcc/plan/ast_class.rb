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
 # class ASTClass
 #  - plan for an AST classes that can be built from our Rules and Forms

   class ASTClass
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :name
      attr_reader :slots
      
      def initialize( name )
         @name  = name
         @slots = []
      end
      
      def define_slot( name, bug_if_duplicate = true )
         bug( "you cannot redefine slot [#{name}]" ) if bug_if_duplicate and @slots.member?(name)
         @slots << name unless @slots.member?(name)
      end
      
      def display( stream = $stdout )
         stream.puts "#{@name} slots:"
         stream.indent do
            @slots.each do |slot|
               stream.puts slot
            end
         end
      end
      
   end # ASTClass
   





end  # module Plan 
end  # module RCC
