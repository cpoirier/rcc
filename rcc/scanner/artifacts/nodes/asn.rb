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
         production.slots.each_index do |index|
            slot = production.slots[index] 
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
         @committed   = false
      end
      
      def ast_class_name()
         return @ast_class.name
      end
      
      
      def []( slot_name )
         if @slots.member?(slot_name) then
            return @slots[slot_name]
         else
            return nil
         end
      end
      
      
      def []=(slot_name, value)
         @slots[slot_name] = value
      end
      
      
      def slot_defined?( slot )
         return @slots.member?(slot)
      end
      
      def slot_filled?( slot )
         return false unless @slots.member?(slot)
         return !@slots[slot].empty? if @slots[slot].is_an?(Array)
         return !@slots[slot].nil?
      end
      
      def define_slot( slot, value )
         @slots[slot] = value
      end

      def method_missing( id, *args )
         name, set = id.to_s.split("=")
         slot      = name
         
         assert( set == "" || set.nil?, "unknown method [#{id.to_s}]"        )
         assert( @slots.member?(slot) , "unknown property or slot [#{name}]" )
         
         if set == "" then
            assert( args.length == 1, "expected 1 value to set into slot [#{name}]")
            @slots[slot] = args[0]
         else
            assert( args.length == 0, "expected 0 values when getting from slot" )
            return @slots[slot]
         end
      end
      
      
      
      # def display( stream = $stdout ) 
      #    stream << "#{@ast_class.name} =>" << "\n"
      # 
      #    stream.indent do
      #       @slots.each do |slot_name, symbol|
      #          stream << slot_name << ":\n"
      #          stream.indent do
      #             symbol.display( stream )
      #          end
      #       end
      #    end
      # end
      # 

      def display( stream = $stdout )
         stream.puts @type
         stream.indent do
            @slots.each do |slot_name, value|
               next if stream[:skip_generated] && slot_name.slice(0..0) == "_"
               stream << slot_name << ":\n"
               stream.indent do
                  self.class.display_node( value, stream )
               end
            end
         end
      end
      
      def self.display_node( node, stream = $stdout )
         case node
         when NilClass
            stream << "<nil>\n"
         when Array
            index = 0
            node.each do |child_node|
               stream << "[#{index}]:\n"
               stream.indent do 
                  display_node( child_node, stream )
               end
               index += 1
            end
         when ASN
            node.display( stream )
         when Token
            node.display( stream )
         when String
            stream.puts( node )
         else
            stream.puts( node.class.name )
         end
      end

      
      
      #
      # commit()
      #  - applies Transformations to this node and its descendents, following REDUCE order

      def commit( recurse = true )
         return true if @committed
         
         #
         # We want to commit in REDUCE order, but we don't want to risk a stack overflow by
         # recursing.  So, we'll build a work queue.  @committed will keep everything straight.

         if recurse then
            expanded   = {}
            work_queue = @slots.values.reverse
            until work_queue.empty?
               asn = work_queue.shift
               next if asn.committed?
            
               if expanded.member?(asn) then
                  asn.commit(false)
               else
                  work_queue.unshift(asn)
                  expanded[asn] = true
                  asn.slots.values.reverse.each do |child_asn| 
                     work_queue.unshift child_asn unless child_asn.token?
                  end
               end
            end
            
            # @slots.each do |name, asn|
            #    asn.commit( true )
            # end
         end
         
         
         #
         # Apply our own Transformations.
         
         @ast_class.transformations.each do |transform|
            transform.apply( self )
         end
         
         @committed = true
         return true
      end
      
      
      def committed?()
         return @committed
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
