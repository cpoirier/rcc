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
require "#{$RCCLIB}/util/sparse_array.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class LexerState
 #  - a representation of a single decision state of a lexer for the Grammar's simple strings

   class LexerState
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :accepted
      attr_reader :child_states

      #
      # initialize()
      #  - each vector should be an array of SparseRanges, one for each character left to be lexed,
      #    followed by the grammar name and symbol name to be produced
      
      def initialize( vectors )
         
         #
         # Build the state data.  We will transition to another state for every first character in the choice
         # list.  We are done when any single-letter choice is matched.
         
         @accepted     = {}
         @child_states = {}
         
         follow_by_firsts = {}
         vectors.each do |vector|
            assert( vector.length >= 3, "wtf?" )
            
            if vector.length == 3 then
               range, grammar_name, symbol_name = *vector
               range.each do |code|
                  @accepted[code] = [grammar_name, symbol_name]
               end
            else
               range = vector.shift
               range.each do |code|
                  follow_by_firsts[code] = [] unless follow_by_firsts.member?(code)
                  follow_by_firsts[code] << vector
               end
            end
         end
         
         follow_by_firsts.each do |first, follows|
            @child_states[first] = self.class.new( follows )
         end
      end
      
      
   end # LexerState
   




end  # module Plan
end  # module RCC
