#!/usr/bin/env ruby
#================================================================================================================================
#
# Ruby Compiler Compiler (rcc)
#
# Copyright 2007 Chris Poirier (cpoirier@gmail.com)
# Licensed under the Academic Free License version 2.1
#
#================================================================================================================================

require "rcc/environment.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class LexerPlan
 #  - a representation of a single decision state of a lexer for the Grammar's Terminals

   class LexerPlan

      
      #
      # build( grammar_model )
      #  - builds a master LexerState that anchor a plan for lexing the supplied Model::Grammar
      
      def self.build( grammar_model )

         #
         # First, separate literal strings from regex and special types.
         
         literals = {}
         other    = []
         
         grammar_model.definitions.each do |name, definition|
            case definition
            when Model::TerminalDefinitions::Simple
               literals[definition.definition] = true
            else
               other << definition
            end
         end
         
         grammar_model.forms.each do |form|
            form.phrases.each do |phrase|
               phrase.symbols.each do |symbol|
                  if symbol.is_a?(Model::FormElements::RawTerminal) then
                     literals[symbol.name] = true
                  end
               end
            end
         end

         return new( literals.keys, "", other, grammar_model.configuration["IgnoreTerminals"].to_s.split(" ").collect{|name| name.intern} )
      end
      
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :context
      attr_reader :tail_processing
      attr_reader :ignore_list
      attr_reader :accepted
      attr_reader :child_states
      
      
      def initialize( choices, context = "", tail_processing = nil, ignore_list = nil )
         @context         = context            # The String that would have already been lexed before getting here
         @tail_processing = tail_processing    # For the outer-most LexerState only (generally), a list of regex and special patterns to attempt if all else fails
         @ignore_list     = ignore_list        # A list of produced tokens to discard as irrelevant (causing a return to lexing)
         
         #
         # Build the state data.  We will transition to another state for every first character in the choice
         # list.  We are done when any single-letter choice is matched.
         
         @accepted     = {}
         @child_states = {}
         
         follow_by_firsts = {}
         choices.each do |choice|
            if choice.length == 1 then
               @accepted[choice] = true
            else
               first  = choice.slice( 0, 1 )
               follow = choice.slice( 1..-1 )
               
               follow_by_firsts[first] = [] unless follow_by_firsts.member?(first)
               follow_by_firsts[first] << follow
            end
         end
         
         follow_by_firsts.each do |first, follows|
            @child_states[first] = LexerState.new( follows )
         end
      end
      
      
      
      
   end # LexerState
   


end  # module Plan
end  # module Rethink
