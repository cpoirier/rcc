#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.dirname(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/util/ordered_hash.rb"

module RCC
module Interpreter

 
 #============================================================================================================================
 # class ASN
 #  - a Node in an Abstract Syntax Tree produced by the Interpreter

   class ASN
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :root_symbol    # The Symbol this CSN represents
      attr_reader :slots          # The named Symbols that comprise it
      attr_reader :ast_class 
      attr_reader :first_token
      attr_reader :last_token
      attr_reader :token_count
      
      alias :symbol :root_symbol
      alias :type   :root_symbol
      
      def initialize( production, component_symbols )
         @root_symbol = production.name
         @ast_class   = production.ast_class
         @slots       = Util::OrderedHash.new()
         @token_count = component_symbols.inject(0) {|sum, symbol| symbol.token_count }
         @first_token = component_symbols[0].first_token
         @last_token  = component_symbols[-1].last_token
         
         production.slot_mappings.each do |index, slot|
            @slots[slot] = component_symbols[index]
         end
      end
      
      def follow_position()
         return @last_token.follow_position
      end
      
      
      def description()
         return "#{@root_symbol}"
      end
      
      def terminal?()
         return false
      end
      
      def display( stream, indent = "", inline_candidate = false )
         stream << indent << "#{@ast_class.name} < #{@ast_class.parent_name} =>" << "\n"
         
         indent1 = indent + "   "
         indent2 = indent1 + "   "
         @slots.each do |slot_name, symbol|
            stream << indent1 << slot_name << ":\n"
            symbol.display( stream, indent2 )
         end
         
         
         return inline_candidate
      end
      
      
      def format( top = true )

         #
         # Assemble our child charts.
         
         child_lines = []
         @slots.each do |slot_name, child|
            if child.is_a?(ASN) then
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
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery 
    #---------------------------------------------------------------------------------------------------------------------


      #
      # tainted?
      #  - returns true if this ASN carries Correction taint
      
      def tainted?()
         return @tainted
      end
      
      
      #
      # untaint()
      #  - clears the taint from this ASN (any Correction is still linked)
      
      def untaint()
         @tainted = false
      end
      
      
      #
      # correction()
      #  - returns the last Correction object associated from within this ASN
      
      def correction()
         return nil if !defined(@correction)
         return @correction 
      end
    
      
    
      
   end # ASN
   


end  # module Interpreter
end  # module Rethink
