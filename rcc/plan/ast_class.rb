#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"

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
      attr_reader :parent_class
      
      def initialize( name, parent_class = nil, is_catch_all = false )
         @name         = name
         @parent_class = parent_class
         @slots        = []
         @catch_all    = nil
         @is_catch_all = is_catch_all
      end
      
      def catch_all?()
         return @is_catch_all
      end
      
      
      def parent_name()
         if @parent_class.nil? then
            return nil
         else
            return @parent_class.name
         end
      end
            
      
      def catch_all_class()
         bug( "get the catchall class from the root class" ) unless @parent_class.nil?
         return @catch_all unless @catch_all.nil?
         @catch_all = ASTClass.new( @name + "_", self, true )
      end
      
      
      def define_slot( name, bug_if_duplicate = true )
         bug( "you cannot redefine slot [#{name}]" ) if bug_if_duplicate and @slots.member?(name)
         @slots << name
      end
      
      
      def merge_slots( production, bug_if_duplicate = true )
         production.slot_mappings.values.each do |slot|
            define_slot( slot, bug_if_duplicate )
         end
      end
      
      
      
   end # ASTClass
   





end  # module Plan 
end  # module Rethink
