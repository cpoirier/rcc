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
require "rcc/plan/lexer_state.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class LexerPlan
 #  - a representation of the overall plan for lexing the Grammar's terminals

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

      attr_reader :literal_processor
      attr_reader :patterns
      attr_reader :fallback_plan
      attr_reader :ignore_list
      
      
      def initialize( literals, patterns = nil, ignore_list = nil, fallback_plan = nil, context = "" )
         @context       = context            # The String that would have already been lexed before getting here
         @literals      = literals           # literal => symbol_name, for literal symbols
         @patterns      = patterns           # OrderedHash of Regexp => symbol_name, for pattern-defined symbols (tried after literals)
         @ignore_list   = ignore_list        # A list of produced tokens to discard as irrelevant (causing a return to lexing)
         @fallback_plan = fallback_plan      # Another LexerPlan to be tried if this one generates no token

         @literal_processor = LexerState.new( literals )
      end
      
      
      #
      # prioritize()
      #  - returns a copy of this LexerPlan in which the named symbols will be identified first
      
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
         # to, we keep the pattern subset in the declaration order.
         
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
