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

module RCC
module Scanner
module Artifacts
module Nodes
   

 
 #============================================================================================================================
 # class CSN
 #  - a Subtree in a Concrete Syntax Tree produced by the Interpreter

   class CSN < Subtree
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :component_nodes   # The Nodes that comprise it
      attr_reader :sub_type
      
      def initialize( type, component_nodes, sub_type = nil )
         @component_nodes = component_nodes
         @sub_type        = sub_type.nil? ? type : sub_type
         component_nodes.each {|node| type_check(node, Scanner::Artifacts::Node, false) }
         super( type, component_nodes )
      end
      
      def []( index )
         return @component_nodes[index]
      end
      
      def first_token
         return @component_nodes[0].first_token
      end
      
      def last_token
         return @component_nodes[-1].last_token
      end
      
      def display( stream, indent = "" )
         stream << indent << "#{@type}" << (@sub_type != @type ? ":#{@sub_type}" : "") << " =>" << "\n"
         
         child_indent = indent + "   "
         @component_nodes.each do |symbol|
            # stream << child_indent << symbol.class.name << "\n"
            symbol.display( stream, child_indent )
         end
      end
      
      def token_count()
         return @component_nodes.length
      end
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Convenience routines
    #---------------------------------------------------------------------------------------------------------------------


      #
      # sequence?
      #  - returns true if this this CSN contains two child nodes, one of this type and one of another type
      
      def sequence?()
         return false unless @component_nodes.length == 2
         return false unless (@component_nodes[0].type == type() or @component_nodes[1].type == type())
         return false if     (@component_nodes[0].type == type() and @component_nodes[1].type == type())
         return true
      end
      
      
      #
      # sequence()
      #  - returns a list of all descendent nodes not of this type
      #  - it's not very smart, so don't expect intelligent results if this isn't a sequence? node
      
      def sequence()
         if !defined?(@sequence) or @sequence.nil? then
            @sequence = []
            each_sequence_member() {|member| @sequence << member }
         end
         
         return @sequence
      end
      
      
      #
      # each_sequence_member()
      #  - iterates over the members of sequence(), if any
      #  - it's not very smart, so don't expect intelligent results if this isn't a sequence? node
      
      def each_sequence_member()
         node           = self
         container_type = type()
         
         done = false
         until done
            done = true
            node.component_nodes.each do |child_node|
               if child_node.type == container_type then
                  node = child_node
                  done = false
               else
                  yield( child_node )
               end
            end
         end
      end

      
   end # CSN
   


end  # module Nodes
end  # module Artifacts
end  # module Scanner
end  # module RCC
