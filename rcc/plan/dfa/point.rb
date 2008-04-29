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
module DFA

 
 #============================================================================================================================
 # DFA 
 #============================================================================================================================
 # Okay, I'm an idiot.  I spent the weekend coming up with a way to convert the ExpressionForms in the LexerPlan into
 # a DFA that could be used both to lex symbols and to generate exemplars of each symbol for use during error recovery,
 # only to think tonight that I probably had an algorithm in one of my books.  Doh! 
 #
 # So, in the long run, I'll probably replace this code again.  However, for now, I'm going to keep it, because it does
 # take measures to make it easy to generate those exemplars.  And it would hurt too much to rewrite it so soon.  :-(  
 # That said, the DFAs here aren't very space-efficient.  Something can probably be done about that, but it might just 
 # be better to rewrite it, when there's time.
 #
 #============================================================================================================================
 # class Point
 #  - a Point in a DFA
 #  - most of the machinery for building the DFA lives here

   class Point


    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :edges
      attr_reader :exit

      def initialize( edges = [], exit = nil)
         @edges = edges
         @exit  = exit
      end

      def empty?()
         return false
      end

      def dup()
         return self.class.new( @edges.collect{|e| e.dup}, @exit )
      end

      def <<( point )
         return PointSet.new( [self, point] )
      end

      def +( point )
         return PointSet.new( [self, point] )
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Operations
    #---------------------------------------------------------------------------------------------------------------------


      #
      # make_edge()
      #  - create and add an Edge to the Point

      def make_edge( inputs, vector = nil )
         vector = context_variable(:vector) if vector.nil?
         involved = PointSet.new()

         prepare_for_inputs( inputs, vector )
         warn_bug( "does prepare_for_inputs() make sense for make_edge()?" )

         @edges.each_index do |index|
            edge    = @edges[index]
            overlap = edge.inputs & inputs
            unless overlap.empty?
               inputs = inputs - overlap

               edge = unroll_cycle(index) if edge.cycle?
               edge.vectors << vector unless edge.vectors.member?(vector)
               involved << edge.target
            end
         end

         unless inputs.empty?
            next_point = Point.new()
            @edges << Edge.new( inputs, [vector], next_point )
            involved << next_point
         end

         return involved.minimal
      end



      #
      # make_cycle()
      #  - adds a Cycle to the Point, or downline, depending on how things are
      #  - if the cycle is more than one edge long, supply a block and it will be called with the leading Point

      def make_cycle( inputs, vector = nil )
         vector = context_variable(:vector) if vector.nil?
         involved = PointSet.new( [self] )

         prepare_for_inputs( inputs, vector )

         #
         # If there are edges in play (not part of this vector), we have to travel across them 
         # before making the cycle.  Consider:
         #
         #   @ =====i|if==== * ====f|if==== @:if
         #                           
         #     ==a-hj-z|id== *
         #
         # If we want to add a cycle for [a-z] at each * position, we can't actually do it at the
         # first one, as there is already an unrelated f edge leaving that point.  We have to unroll
         # the cycle from that point until we are clear of unrelated edges.  However, each point we
         # pass through is part of the point set we return (any one of them could be used when 
         # the cycle occurs 0 times).

         in_play = @edges.select{|e| !e.vectors.member?(vector)}
         if !in_play.empty? then
            remaining_inputs = inputs
            in_play.each do |edge|
               overlap = edge.inputs & inputs
               unless overlap.empty?
                  remaining_inputs = remaining_inputs - edge.inputs
                  edge.vectors << vector

                  if edge.cycle? then
                     warn_bug( "what should make_cycle() do with in_play CycleEdges?" )
                  else
                     involved << edge.target
                     if block_given? then
                        involved << edge.target.make_cycle(inputs, vector) {|cp| yield(cp)}
                     else
                        involved << edge.target.make_cycle(inputs, vector)
                     end
                  end
               end
            end

            unless remaining_inputs.empty?
               p = make_edge( remaining_inputs, vector )
               if block_given? then
                  involved << p.make_cycle(inputs, vector){|cp| yield(cp)}
               else
                  involved << p.make_cycle( inputs, vector )
               end
            end

         #
         # Also note that we can't add a cycle at an element with an unrelated exit.  If we did, we'd
         # end up allowing additional characters before an existing exit.  So, again, we have to unroll
         # the cycle at such positions.

         elsif @exit.exists? and @exit != vector then
            p = make_edge( inputs, vector )
            if block_given? then
               involved << p.make_cycle(inputs, vector){|cp| yield(cp)}
            else
               involved << p.make_cycle(inputs, vector)
            end


         #
         # Otherwise, it's clear sailing.

         else
            cycle = CycleEdge.new( inputs, [vector] )
            @edges << cycle
            if block_given? then
               next_point = Point.new()
               cycle.target = next_point
               yield( next_point )
               cycle.terminate_cycle()
            end
         end


         return involved.minimal
      end


      #
      # make_exit()
      #  - set the exit, if it hasn't already been set
      
      def make_exit( vector = nil )
         vector = context_variable(:vector) if vector.nil?
         if @exit.nil? then 
            @exit = vector
            return self
         else
            return nil
         end
      end


      #
      # make()
      #  - provides context for writing an entire vector into this Point
      #  - pass a block that fills in the vector and returns the PointSet to make_exit()
      
      def make( vector, backup = true )
         old_edges = backup ? @edges.collect{|e| e.dup} : nil
         old_exit  = @exit

         with_context_variable( :vector, vector ) do 
            exits = yield(self).make_exit()
            if (exits.nil? or exits.empty?) and backup then
               @edges = old_edges
               @exit  = old_exit
            end
         end
      end



    #---------------------------------------------------------------------------------------------------------------------
    # Output
    #---------------------------------------------------------------------------------------------------------------------


      def display( stream = $stdout )
         edge_data = []
         @edges.each do |edge|
            edge_data << [(edge.inputs.to_s + "|" + edge.vectors.join(",")), edge.target, edge.cycle?]
         end

         width  = edge_data.inject(0){|w, e| max(w, e[0].length)}
         marker = "@" + (@exit.nil? ? " " : ":#{@exit}   ")

         stream << marker
         stream.indent(" " * marker.length) do 
            edge_data.each do |datum|
               label, target, cycle = *datum

               edge = cycle ? "***" : "==="

               formatted = edge + label.center(width).gsub(/(^\s+)|(\s+$)/){|s| "=" * s.length} + edge + "   "
               stream << formatted
               stream.indent(" " * formatted.length) do
                  target.display(stream)
               end
               if cycle then 
                  stream.end_line
                  stream.puts "<==== return ===="
                  stream.puts
               end
               stream.end_line
            end
         end
      end
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Internals
    #---------------------------------------------------------------------------------------------------------------------

      #
      # prepare_for_inputs()
      #  - does any prepatory work necessary to allow the supplied inputs to be processed:
      #     - ensures the edges can be addressed uniquely across the specified inputs
      #     - unrolls any cycles that are unrelated to the current operation and that shouldn't
      #       interfere with or be interered with by them

      def prepare_for_inputs( inputs, vector )
         original = nil
         original = self.dup if @edges.any?{|e| e.cycle? and !e.vectors.member?(vector) and (inputs != e.inputs)}

         fork_edges( inputs )
         @edges.each_index do |index|
            edge = @edges[index]
            unroll_cycle( index, original ) if (edge.cycle? and !edge.vectors.member?(vector) and (inputs & edge.inputs).empty?)
         end
      end
      

      #
      # unroll_cycle()
      #  - "unrolls" a single cycle so that it leaves on an edge, pushing the cycle to the next Point

      def unroll_cycle( index, terminus = nil )
         terminus = self.dup if terminus.nil?
         assert( @edges[index].cycle?, "you can only unroll a CycleEdge!" )

         @edges[index] = @edges[index].unroll( terminus )
      end


      #
      # fork_edges()
      #  - teases apart any edges that partially overlap the supplied inputs
      
      def fork_edges( inputs )
         changed = false
         finished = []
         @edges.each do |edge|
            overlap   = edge.inputs & inputs
            remainder = edge.inputs - overlap

            if overlap.empty? or remainder.empty? then
               finished << edge
            else
               fork = edge.dup
               fork.inputs.replace( remainder )
               edge.inputs.replace( overlap )

               finished << edge
               finished << fork

               changed = true
            end
         end

         @edges = finished if changed
      end
    
   end



end  # module DFA
end  # module Plan
end  # module RCC


require "#{$RCCLIB}/plan/dfa/point_set.rb"
require "#{$RCCLIB}/plan/dfa/edge.rb"
require "#{$RCCLIB}/plan/dfa/cycle_edge.rb"




if $0 == __FILE__ then
   require "#{$RCCLIB}/util/sparse_range.rb"
   SparseRange = RCC::Util::SparseRange
   Point       = RCC::Plan::DFA::Point
   
   $stdout.puts "Example 1:"
   $stdout.puts "   if    => 'if'"
   $stdout.puts "   id    => [a-zA-Z][a-zA-Z0-9_]*"
   $stdout.puts "   any   => [\0000-\ffff]+"
   $stdout.blank_lines(2)
   $stdout.indent do
      start = Point.new()
   
      start.make('if'   ) {|p| p.make_edge(SparseRange.new(105)).make_edge(SparseRange.new(102)) }
      start.make('id'   ) {|p| p.make_edge(SparseRange.new(97..122, 65..90)).make_cycle(SparseRange.new(97..122, 65..90, 48..57, 95)) }
      start.make('any'  ) {|p| p.make_edge(SparseRange.new(0..65536)).make_cycle(SparseRange.new(0..65536)) }
   
      start.display( $stdout )
   end
   
   
   $stdout.blank_lines(3)
   
   
   $stdout.puts "Example 2:"
   $stdout.puts "   complex => b([ab]|m[cd]q)*d"
   $stdout.puts "   simple  => b*l"
   $stdout.blank_lines(2)
   $stdout.indent do
      start = Point.new()
      
      start.make('complex') do |p|
         branch_point = p.make_edge(SparseRange.new(98))
         r = branch_point.make_cycle(SparseRange.new(97..98)) + 
             branch_point.make_cycle(SparseRange.new(109)) do |c|
                c = c.make_edge( SparseRange.new(99..100) )
                c = c.make_edge( SparseRange.new(113) )
             end
         r.make_edge(SparseRange.new(100))
      end
   
      start.make('simple') {|p| p.make_cycle(SparseRange.new(98)).make_edge(SparseRange.new(108)) }
      
      start.display( $stdout )
   end
   
   
   $stdout.blank_lines(3)
   
   
   $stdout.puts "Example 3:"
   $stdout.puts "   x => [a-z][a-z][0-9]*"
   $stdout.puts "   y => [a-z]+[A-Z]"
   $stdout.puts "   z => [a-z]+"
   $stdout.blank_lines(2)
   $stdout.indent do
      start = Point.new()
      
      start.make('x') {|p| p.make_edge(RCC::Util::SparseRange.new(97..122)).make_edge(RCC::Util::SparseRange.new(97..122)).make_cycle(RCC::Util::SparseRange.new(48..57)) }
      start.make('y') {|p| p.make_edge(RCC::Util::SparseRange.new(97..122)).make_cycle(RCC::Util::SparseRange.new(97..122)).make_edge(RCC::Util::SparseRange.new(65..90)) }
      start.make('z') {|p| p.make_edge(RCC::Util::SparseRange.new(97..122)).make_cycle(RCC::Util::SparseRange.new(97..122)) }

      start.display( $stdout )
   end

   
   $stdout.blank_lines(3)
   
   
   $stdout.puts "Example 4:"
   $stdout.puts "   x => [a-z]+[A-Z]"
   $stdout.puts "   y => [a-z]+"
   $stdout.puts "   z => [a-z][a-z][0-9]*"
   $stdout.blank_lines(2)
   $stdout.indent do
      start = Point.new()
      
      start.make('x') {|p| p.make_edge(RCC::Util::SparseRange.new(97..122)).make_cycle(RCC::Util::SparseRange.new(97..122)).make_edge(RCC::Util::SparseRange.new(65..90)) }
      start.make('y') {|p| p.make_edge(RCC::Util::SparseRange.new(97..122)).make_cycle(RCC::Util::SparseRange.new(97..122)) }
      start.make('z') {|p| p.make_edge(RCC::Util::SparseRange.new(97..122)).make_edge(RCC::Util::SparseRange.new(97..122)).make_cycle(RCC::Util::SparseRange.new(48..57)) }

      start.display( $stdout )
   end
   
end

