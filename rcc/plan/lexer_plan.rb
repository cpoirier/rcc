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
      #  - builds a master LexerPlan that anchor a plan for lexing the supplied Model::Grammar
      
      def self.build( grammar_model )

         #
         # First, separate literal strings from regex and special types.
         
         literals = {}
         patterns = Util::OrderedHash.new()
         
         grammar_model.definitions.each do |name, definition|
            case definition
            when Model::TerminalDefinitions::Simple
               literals[definition.definition] = name.intern
            when Model::TerminalDefinitions::Pattern
               patterns[definition.regexp    ] = name.intern
            else
               bug "there are no other types!"
            end
         end
         
         grammar_model.forms.each do |form|
            form.phrases.each do |phrase|
               phrase.symbols.each do |symbol|
                  if symbol.is_a?(Model::FormElements::RawTerminal) then
                     literals[symbol.name] = symbol.name unless literals.member?(symbol.name)
                  end
               end
            end
         end

         return new( literals, patterns, grammar_model.ignore_terminals.collect{|name| name.intern} )
      end
      
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :context
      attr_reader :accepted
      attr_reader :child_states
      attr_reader :patterns
      attr_reader :tail_processing
      attr_reader :ignore_list
      
      
      def initialize( literals, patterns = nil, ignore_list = nil, tail_processing = nil, context = "" )
         @context         = context            # The String that would have already been lexed before getting here
         @literals        = literals           # literal => symbol_name, for literal symbols
         @patterns        = patterns           # OrderedHash of Regexp => symbol_name, for pattern-defined symbols (tried after literals)
         @ignore_list     = ignore_list        # A list of produced tokens to discard as irrelevant (causing a return to lexing)
         @tail_processing = tail_processing    # Another LexerPlan to be tried if this one generates no token
         
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
            @child_states[first] = self.class.new( follows, nil, nil, nil, @context + first )
         end
      end
      
      
      
      #
      # prioritize()
      #  - returns a copy of this LexerPlan in which the named symbols will be identified first
      #  - you should probably only call this on the top LexerPlan
      
      def prioritize( symbol_names, maintain_ordering = true )
         
         #
         # Index our symbol names, if not already done.
         
         if @literal_lookup.nil? then
            @literal_lookup = {}
            @literals.each do |literal, symbol_name|
               @literal_lookup[symbol_name] = literal
            end
            
            @pattern_lookup = {}
            @patterns.each do |pattern, symbol_name|
               @pattern_lookup[symbol_name] = pattern
            end
         end
         
         
         #
         # Pick those symbols we'll need to prioritize.  We don't really care about literals order, but unless asked not
         # to, we keep the pattern subset in the original order.
         
         literals = {}
         patterns = Util::OrderedHash.new()
         
         symbol_names.each do |symbol_name|
            if symbol_name.nil? then
               # no op -- this is the end of input marker
            elsif @literal_lookup.member?(symbol_name) then
               literals[@literal_lookup[symbol_name]] = symbol_name
            elsif @pattern_lookup.member?(symbol_name) then
               patterns[@pattern_lookup[symbol_name]] = symbol_name
            else
               bug "can't prioritize unknown symbol_name [#{symbol_name}]"
            end
         end


         #
         # If there are no patterns in the selected set, we don't actually need to change anything, as prioritize()
         # is really about increasing the precedence of pattern processing.  The DFA that handles literals will 
         # produce the same results, regardless of ordering.  We can also use the current LexerPlan if any patterns
         # requested would be the first patterns processed anyway.
         #
         # Otherwise, we produce a new LexerPlan, backed by us.
         
         if patterns.empty? then
            return self
         else
            patterns.reorder( @patterns.order ) if maintain_ordering
            
            if patterns.order == @patterns.order.slice(0..patterns.length) then
               return self
            else
               return self.class.new( literals, patterns, @ignore_list, self, @context )
            end
         end
      end


      
      
   end # LexerPlan
   




end  # module Plan
end  # module Rethink
