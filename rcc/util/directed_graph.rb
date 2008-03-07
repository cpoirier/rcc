#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2004, 2007, 2008 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"

module RCC
module Util

 
 #============================================================================================================================
 # class DirectedGraph
 #  - manages a set of directed relationships between nodes, allowing you to find out if one node is connected to another

   class DirectedGraph

      def initialize( by_reference = true )
         @by_reference = by_reference

         @from   = {}    # { from object id => [ to object*   ] } - relationships keyed on from
         @to     = {}    # { to object id   => [ from object* ] } - relationships keyed on to

         @nodes  = {}    # { object id => Object    } - all nodes engaged in relationships
         @points = {}    # { object id => Object    } - all known non-member nodes -- points are moved to @node on register()
      end

      def nodes()
         return @nodes.values()
      end

      def points()
         return @points.values()
      end
      
      def members()
         return (@nodes.values() + @points.values())
      end

      def from?( from )
         return @from.member?(@by_reference ? from.object_id : from)
      end

      def to?( to )
         return @to.member?(to)
      end

      def node?( node )
         return @nodes.member?(@by_reference ? node.object_id : node)
      end

      def point?( node )
         return @points.member?(@by_reference ? node.object_id : node)
      end

      def member?( node )
         return (point?(node) or node?(node))
      end

      def length()
         return @nodes.length
      end
      
      def children_of( node )
         return @from[@by_reference ? node.object_id : node] if @from.member?(@by_reference ? node.object_id : node)
         return []
      end
      
      def parents_of( node )
         return @to[@by_reference ? node.object_id : node] if @to.member?(@by_reference ? node.object_id : node)
         return []
      end
      
      def register( from, to )
         unless @from.member?(@by_reference ? from.object_id : from) and @from[@by_reference ? from.object_id : from].member?(to) then
            if @from.member?(@by_reference ? from.object_id : from) then
               @from[@by_reference ? from.object_id : from] << to
            else
               @from[@by_reference ? from.object_id : from] = [ to ]
            end

            if @to.member?(@by_reference ? to.object_id : to) then
               @to[@by_reference ? to.object_id : to] << from
            else
               @to[@by_reference ? to.object_id : to] = [ from ]
            end

            @nodes[@by_reference ? from.object_id : from] = from unless @nodes.member?(from)
            @nodes[@by_reference ? to.object_id : to]   = to   unless @nodes.member?(to)

            @points.delete( @by_reference ? from.object_id : from )
            @points.delete( @by_reference ? to.object_id   : to   )

            return true
         else
            return false
         end
      end


      #
      # Registers a point not (yet) connected to the graph.  After the graph is
      # built, @points will contain those points still not connected.

      def register_point( point )
         @points[@by_reference ? point.object_id : point] = point unless member?(point)
      end

   end  


end  # module Util
end  # module RCC


