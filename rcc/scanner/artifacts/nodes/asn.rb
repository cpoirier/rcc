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
require "#{$RCCLIB}/scanner/artifacts/nodes/subtree.rb"
require "#{$RCCLIB}/util/ordered_hash.rb"


module RCC
module Scanner
module Artifacts
module Nodes

 
 #============================================================================================================================
 # class ASN
 #  - a Subtree Node in an Abstract Syntax Tree produced by the Scanner

   class ASN < Subtree
      
      def self::map( production, component_nodes )
         slots = Util::OrderedHash.new()
         production.slots.each do |index, slot|
            slots[slot] = component_nodes[index] unless slot.nil?
         end
         
         return new( production.name, component_nodes, slots, production.ast_class )
      end
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :slots          # The named Symbols that comprise it
      attr_reader :ast_class 
      attr_reader :first_token
      attr_reader :last_token
      
      def initialize( type, component_nodes, slots, ast_class = nil )
         super( type, component_nodes )
         @ast_class   = ast_class
         @slots       = slots
         @first_token = component_nodes[0].first_token
         @last_token  = component_nodes[-1].last_token
      end
      
      def ast_class_name()
         return @ast_class.name
      end
      
      def display( stream = $stdout ) 
         stream << "#{@ast_class.name} < #{@ast_class.parent_name} =>" << "\n"

         stream.indent do
            @slots.each do |slot_name, symbol|
               stream << slot_name << ":\n"
               stream.indent do
                  symbol.display( stream )
               end
            end
         end
         
         return inline_candidate
      end
      
      
      def format( top = true )

         #
         # Assemble our child charts.
         
         child_lines = []
         @slots.each do |slot_name, child|
            if child.is_an?(ASN) then
               if child.ast_class.catch_all? and child.slots.length == 1 then
                  leader = slot_name + "."
                  child.format(false).each do |line|
                     child_lines << leader + line
                     leader = "  "
                  end
               else
                  child_lines << slot_name + ":"
                  child.format(false).each do |line|
                     child_lines << "  " + line 
                  end
               end
            else
               child_lines << slot_name + ": " + child.description
            end
         end
         
         #
         # Assemble our chart from our child data.

         chart = []
         if !top and @ast_class.catch_all? and @slots.length == 1 then
            chart.concat child_lines
         else
            child_width = 0
            child_lines.each do |child_line|
               child_width = max( child_line.length, child_width )
            end
         
            class_name = @ast_class.catch_all? ? @ast_class.parent_class.name : @ast_class.name
            width      = max( child_width, class_name.length ) + 3
            horizontal = "+" + ("-" * width) + "+"
         
            chart << horizontal
            chart << ("| " + class_name + (" " * (width - class_name.length - 1)) + "|")
            chart << horizontal
            child_lines.each do |child_line|
               chart << ("| " + child_line.ljust(width - 3) + "  |")
            end
            chart << horizontal
         end
         
         return chart
      end
      
      
      
      
   end # ASN
   


end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC
