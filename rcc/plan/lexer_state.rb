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

module RCC
module Plan

 
 #============================================================================================================================
 # class LexerState
 #  - a representation of a single decision state of a lexer for the Grammar's literal Terminals

   class LexerState
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :context
      attr_reader :accepted
      attr_reader :child_states
      
      def initialize( literals, context = "" )
         @context = context    # The String that would have already been lexed before getting here
         
         #
         # Build the state data.  We will transition to another state for every first character in the choice
         # list.  We are done when any single-letter choice is matched.
         
         @accepted     = {}
         @child_states = {}
         
         follow_by_firsts = {}
         literals.keys.each do |literal|
            if literal.length == 1 then
               @accepted[literal] = literals[literal]
            else
               first  = literal.slice( 0, 1 )
               follow = literal.slice( 1..-1 )
               
               follow_by_firsts[first] = {} unless follow_by_firsts.member?(first)
               follow_by_firsts[first][follow] = literals[literal]
            end
         end
         
         follow_by_firsts.each do |first, follows|
            @child_states[first] = self.class.new( follows, @context + first )
         end
      end
      
      
   end # LexerState
   




end  # module Plan
end  # module Rethink
