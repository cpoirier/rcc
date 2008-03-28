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
require "#{$RCCLIB}/plan/lexer_state.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class LexerPlan
 #  - a representation of the overall plan for lexing the Grammar's terminals

   class LexerPlan

      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :literal_processor
      attr_reader :closed_patterns
      attr_reader :open_patterns
      attr_reader :fallback_plan
      
      
      def initialize( fallback_plan = nil, closed_patterns = [], open_patterns = [] )
         @closed_patterns = closed_patterns       # ExpressionForm patterns that are not complex and do not overlap, and should be tried first
         @open_patterns   = open_patterns         # ExpressionForm patterns that may be complex and must be tried in order
         @fallback_plan   = fallback_plan         # Another LexerPlan to be tried if this one generates no token
         @lexer_state     = nil
      end
      
      
      #
      # add_closed_pattern()
      #  - adds a closed pattern to the plan
      #  - closed patterns can be processed in any order, and must be unique across all closed patterns
      
      def add_closed_pattern( grammar_name, symbol_name, expression )
         assert( @lexer_state.nil?, "you cannot add_pattern()s to this LexerPlan after close()ing it" )
         @closed_patterns << [grammar_name, symbol_name, expression]
      end
      
      
      #
      # add_open_pattern()
      #  - adds an open pattern to the plan
      #  - open patterns must be processed in added order, and may overlap each other
      
      def add_open_pattern( grammar_name, symbol_name, expression )
         assert( @lexer_state.nil?, "you cannot add_pattern()s to this LexerPlan after close()ing it" )
         @open_patterns << [grammar_name, symbol_name, expression]
      end
      
      
      #
      # each_open_pattern()

      def each_open_pattern()
         @open_patterns.each do |line|
            yield( line[0], line[1], line[2] )
         end
      end

      
      #
      # lexer_state()
      
      def lexer_state()
         
         if @lexer_state.nil? then
            
            #
            # Organize the @closed_patterns into something that can be represented by a LexerState.
            # Closed patterns have no branching or anything else, so we can just convert them to arrays
            # of SparseRanges.
         
            vectors = []
            @closed_patterns.each do |descriptor|
               grammar_name, symbol_name, sequence = *descriptor
            
               vectors << (sequence.elements + [grammar_name, symbol_name])
            end

            @lexer_state = LexerState.new( vectors )
         end
         
         return @lexer_state
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Context-sensitizing
    #---------------------------------------------------------------------------------------------------------------------
    
      #
      # prioritize()
      #  - returns a copy of this LexerPlan in which the named symbols will be identified first
      #  - symbol_names must be an array of [grammar_name, symbol_name], or a single grammar name (for the whole grammar)
      
      
      def prioritize( names )
         
         #
         # Collect the expressions we are prioritizing, maintain declaration order within the set.
         
         closed_patterns = []
         open_patterns   = []
         if names.is_a?(String) then
            grammar_name = names
            [[@closed_patterns, closed_patterns], [@open_patterns, open_patterns]].each do |pair|
               from, to = *pair
               to = from.select{|descriptor| descriptor[0] == grammar_name}
            end
         else

            #
            # When processing a list of [grammar_name, symbol_name], we want to prioritize the named expressions
            # while maintaining the declaration order of the prioritized expressions. 
            
            index = {}
            names.each do |name_pair|
               grammar_name, symbol_name = *name_pair
               index[grammar_name] = {} unless index.member?(grammar_name)
               index[grammar_name][symbol_name] = true
            end
            
            [[@closed_patterns, closed_patterns], [@open_patterns, open_patterns]].each do |pair|
               from, to = *pair
               to = from.select{|descriptor| index.member?(descriptor[0]) and index[descriptor[0]].member?(descriptor[1]) }
            end
         end
         
         
         #
         # If there is no effective change in order between the produced set and this LexerPlan,
         # just return self.  Otherwise, construct a new LexerPlan.

         return self if (open_patterns.empty? and closed_patterns.empty?)
         return self if open_patterns == @open_patterns.order.slice(0..open_patterns.length) and closed_patterns == @closed_patterns.order.slice(0..closed_patterns.length)
         return self.class.new( self, closed_patterns, open_patterns )
      end


      
      
   end # LexerPlan
   




end  # module Plan
end  # module RCC
