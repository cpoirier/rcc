#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2004, 2007-2008 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/rcc/")[0..-2].join("/rcc/")}/rcc/environment.rb"
require "#{$RCCLIB}/util/directed_graph.rb"


module RCC
module Util

 
 #============================================================================================================================
 # class DirectedAcyclicGraph
 #  - manages a set of directed relationships between nodes
 #  - allows no cycles (strict hierarchies only)

   class DirectedAcyclicGraph < DirectedGraph 
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      def initialize( by_reference = true )
         super( by_reference )

         @roots     = {}   # { node object id => node } - those from nodes that aren't pointed to
         @leaves    = {}   # { node object id => node } - those to nodes that don't point to other nodes

         @distances = {}   # { node => steps from node to a root } - working space for layerize()
         @layers    = nil  # { steps to root => [ node ] } - results of layerize(), the graph organized into layers
      end

      def roots( include_points = true )
         if include_points then
            return (@roots.values() + @points.values())
         else
            return @roots.values()
         end
      end

      def leaves( include_points = false )
         if include_points then
            return (@leaves.values() + @points.values())
         else
            return @leaves.values()
         end
      end

      def layers()
         layerize() if @layers.nil?
         return @layers.keys.length
      end

      def layer( index )
         layerize() if @layers.nil?
         return @layers[index]
      end


      #
      # independent_trees()
      #  - returns a list of DAGs, for each isolated set of nodes in this one
      #  - if you supply a list of point_sets, they will be used to ensure nodes end up in the same DAG
      
      def independent_trees( *point_sets )
         results = []
         
         roots = @roots.values + @points.values
         until roots.empty?
            
            #
            # Get the next root and see if it has already been used.  If it has, we're done with it.
            
            root = roots.shift
            used = false
            results.each do |result_tree|
               if result_tree.member?(root) then
                  used = true
                  break
               end
            end
            
            next if used
            
            #
            # Initialize the work_queue and create a tree to hold the results.  Use the work_queue to
            # traverse every node reachable from the root (up or down).

            tree       = self.class.new( @by_reference )
            work_queue = [ root ]

            until work_queue.empty?
               until work_queue.empty?
                  node = work_queue.shift
                  tree.register_point( node )
               
                  parents_of(node).each do |parent|
                     work_queue << parent unless tree.member?(parent)
                     tree.register( parent, node )
                  end
               
                  children_of(node).each do |child|
                     work_queue << child unless tree.member?(child)
                     tree.register( node, child )
                  end
               end
               
               #
               # For any point_set that includes nodes from the tree, add the other points to the 
               # work_queue.
               
               point_sets.each do |point_set|
                  point_set.each do |point|
                     if tree.member?(point) then
                        point_set.each do |point|
                           work_queue << point unless tree.member?(point)
                        end
                        
                        break
                     end
                  end
               end
            end
            
            #
            # Finish up.
            
            results << tree
         end
         
         return results
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Iterators
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # each_layer()
      #  - calls your block once for each layer, passing the layer node list
      #  - starts with the roots, unless from_root is false
      
      def each_layer( from_root = true )
         layerize() if @layers.nil?

         if from_root then
            layers().times do |index|
               yield( layer(index) )
            end
         else
            (layers()-1).downto(0) do |index|
               yield( layer(index) )
            end
         end
      end


      #
      # each_layer_reverse()
      #  - calls your block once for each layer, passing the layer node list
      #  - starts with the leaves
      
      def each_layer_reverse()
         each_layer(false) do |layer|
            yield( layer )
         end
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Node Searches
    #---------------------------------------------------------------------------------------------------------------------
      
      #
      # root?()
      #  - returns true if the specified node is a root (no node points to it)
      
      def root?( node )
         return @roots.member?(@by_reference ? node.object_id : node)
      end


      #
      # leaf?()
      #  - returns true if the specified node is a leaf (points to no nodes)
      
      def leaf?( node )
         return @leaves.member?(@by_reference ? node.object_id : node)
      end


      #
      # would_cycle?()
      #  - returns true if adding either of these nodes to the graph would produce a cycle (which isn't allowed in an 
      #    acyclic graph).

      def would_cycle?( from, to )
         if from == to then
            return true
         elsif not node?(from) or not node?(to) then
            return false
         else
            links = @from[@by_reference ? to.object_id : to]
            if links.nil? then
               return false
            else
               links.each do |to_to|
                  if would_cycle?( from, to_to ) then
                     return true
                  end
               end
            end
         end

         return false
      end


      #
      # path?
      #  - returns true if you can get to the second node starting from the first and moving only forward

      def path?( from, to )
         return true  if (@by_reference ? from.object_id : from == @by_reference ? to.object_id : to and member?(from))
         return false unless node?(from) and node?(to)

         links = @from[@by_reference ? from.object_id : from]
         return false if links.nil?

         links.each do |step|
            return true if path?( step, to )
         end

         return false
      end


      #
      # path()
      #  - returns the nodes connecting from to to, and including from and to as endpoints

      def path( from, to )
         return [from] if (@by_reference ? from.object_id : from == @by_reference ? to.object_id : to and member?(from))
         return []     unless node?(from) and node?(to)

         links = @from[@by_reference ? from.object_id : from]
         return [] if links.nil?

         links.each do |step|
            path = path( step, to )
            if path then
               return [from] + path
            end
         end
         
         return []
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Node Registration
    #---------------------------------------------------------------------------------------------------------------------

      #
      # register()
      #  - links two objects into the graph
      
      def register( from, to, check_for_cycles = true )
         layers = nil

         if check_for_cycles then
            return false if would_cycle?( from, to )
         end

         #
         # Register or deregister roots and leaves, appropriately.

         if node?(from) then
            if leaf?(from) then
               @leaves.reject! do |id, leaf|
                  @by_reference ? from.object_id : from == id
               end
            end
         else
            @roots[@by_reference ? from.object_id : from] = from
         end

         if node?(to) then
            if root?(to) then
               @roots.reject! do |id, root|
                  @by_reference ? to.object_id : to == id
               end
            end
         else
            @leaves[@by_reference ? to.object_id : to] = to
         end

         #
         # Chain to super to handle everything else.

         return super( from, to )
      end
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Private Operations
    #---------------------------------------------------------------------------------------------------------------------
 
    private 

      #
      # layerize()
      #  - traverses the graph and organizes it into layers by the minimum and maximum distance each node is from a root
      #  - roots have a distance of 0
      #  - default operation is to organize layers by maximum distance from node to a root
      #  - points are treated as roots

      def layerize( by_maximum_distance = true )
         @distances = {}
         @layers    = {}
         
         @layers[0] = @points.values() unless @points.empty?

         @nodes.each do |key, node|
            calculate_distance_from_root( node, by_maximum_distance )
         end

         @distances.each do |key, distance|
            if @layers.member?(distance) then
               @layers[distance] << @nodes[key]
            else
               @layers[distance] = [@nodes[key]]
            end
         end

         @distances = {}
      end


      #
      # calculate_distance_from_root()
      #  - like the name says
      #  - used by layerize()
      
      def calculate_distance_from_root( node, by_maximum_distance )
         unless @distances.member?(@by_reference ? node.object_id : node)
            if @roots.member?(@by_reference ? node.object_id : node) then
               @distances[@by_reference ? node.object_id : node] = 0
            else
               distance = by_maximum_distance ? 0 : 1000000000

               @to[@by_reference ? node.object_id : node].each do |path|
                  steps = calculate_distance_from_root( path, by_maximum_distance ) + 1
                  distance = by_maximum_distance ? max(distance, steps) : min(distance, steps)
               end

               @distances[@by_reference ? node.object_id : node] = distance
            end
         end

         return @distances[@by_reference ? node.object_id : node]
      end


   end # DirectedAcyclicGraph
   


end  # module Util
end  # module RCC




if $0 == __FILE__ then
   
   #
   # Validate independent_trees().
   #
   #    a    d g   h i
   #   b c   e f
   
   setup = RCC::Util::DirectedAcyclicGraph.new( false )
   setup.register( "a", "b" )
   setup.register( "a", "c" )
   setup.register( "d", "e" )
   setup.register( "d", "f" )
   setup.register( "g", "e" )
   setup.register( "g", "f" )
   setup.register_point( "h" )
   setup.register_point( "i" )
   
   setup.independent_trees( ["a"], ["d", "g"], ["h", "i"] ).each do |tree|
      puts "in #{tree.members.join(", ")}:"
      
      tree.each_layer do |layer|
         puts layer.join( ", " )
      end
      
      puts ""
   end
   
   
   
   
   
end
