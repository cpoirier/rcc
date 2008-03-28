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
require "#{$RCCLIB}/scanner/artifacts/nodes/token.rb"


module RCC
module Scanner
module Interpreter

 
 #============================================================================================================================
 # class Lexer
 #  - an reversible interpreter for LexerPlans sourced from LexerPlan States

   class Lexer
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and public interface
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :next_position
      
      def initialize( source )
         @source         = source       # The Source from where we will draw our input
         @start_position = 0            # The position at which we started the current read()
         @next_position  = 0            # The position following the previous read()
      end
      
      
      #
      # read()
      #  - reads a single Token from the source, starting at the specified position, using
      #    the supplied LexerPlan
      #  - returns Token::end_of_file on the end of input
      
      def read( position, lexer_plan, estream = nil )
         position = @next_position if position.nil?
         
         warn_nyi( "error handling in lexer" )

         if @source.at_eof?(position) then
            return nil
         else
            @start_position = position 
            token           = nil
            line_number     = @source.line_number(position)
            column_number   = @source.column_number(position)
         
            unless solution = read_via_lexer_state( position, lexer_plan.lexer_state, estream )
               lexer_plan.each_open_pattern do |grammar_name, symbol_name, form|
                  break if solution = read_via_pattern( position, form, grammar_name, symbol_name, estream )
               end
            end
         
            if solution then
               token = solution.to_Token( position, line_number, column_number, @source )
               @next_position = token.follow_position
            else
            
               #
               # If we couldn't produce a Token, perhaps there is another LexerPlan to try.
            
               if lexer_plan.fallback_plan then
                  if lexer_plan.fallback_plan.nil? then
                     estream.puts "there is no fallback plan for this lexer" if estream
                  else
                     estream.puts "attempting fallback plan" if estream
                     token = read( position, lexer_plan.fallback_plan, estream )
                  end
               end
            end
         
            return token
         end

         # if estream then
         #    if token.nil? then
         #       if input_remaining?() then
         #          estream.puts "===> ERROR LEXING: #{prep(@pending_lines[0])}; will PRODUCE one-character token of unknown type"
         #       else
         #          estream.puts "===> DONE"
         #       end
         #    else
         #       estream.puts "===> PRODUCING #{token.description} at #{token.line_number}:#{token.column_number}, position #{token.start_position}"
         #    end
         # end
         # 
         # if token.nil? then
         #    if input_remaining?() then
         #       return locate_token( Artifacts::Token.new(consume()), false )
         #    else
         #       return Artifacts::Token.end_of_file( @position, @line_number, @column_number, @descriptor )
         #    end
         # else
         #    return token
         # end
         

      end
      
      
      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Token production
    #---------------------------------------------------------------------------------------------------------------------
    
    protected

      #
      # read_via_lexer_state()
      #  - processes a LexerState against the current lookahead
      #  - returns a Solution if the lookahead matches the state, or nil
      
      def read_via_lexer_state( position, state, estream = nil )
         solution = nil
         note     = nil
         
         #
         # First, try to read by character lookahead.  Note that for "+" and "++", "+" will match both
         # a child_plan and an accepted entry.  So we try the child_plan first.  If it fails, we'll try
         # accept instead.  In other words, we take the longest match we can.  
         
         if c = @source[position] then
            note = "source[#{position}] (+#{position - @start_position}) = #{sprintf("\\u%04X", c)};" if estream
            
            if state.child_states.member?(c) then
               estream.puts "#{note} matches a child state; trying child state [#{state.object_id}]" if estream
               solution.prepend( c ) if solution = read_via_lexer_state(position + 1, state.child_states[c], estream)
            end
      
            if solution.nil? and state.accepted.member?(c) then
               estream.puts "#{note} is accepted by state [#{state.object_id}]; producing type #{state.accepted[c].join(".")}" if estream
               solution = Solution.new( c, *state.accepted[c] )
            end
            
            if solution.nil? then
               estream.puts "#{note} does not match any literal options in this state" if estream
            end
         end
         
         return solution
      end
      
      
      
      #
      # read_via_pattern()
      #  - processes an ExpressionForm of SparseRanges against the source to produce
      #    a matching string of characters (longest match possible) or nil
      
      def read_via_pattern( position, form, grammar_name, symbol_name, estream = nil )
         solution = nil
         
         if estream then
            description = "attempting pattern [#{grammar_name}.#{symbol_name}]   ".ljust(50)
            
            estream << description 
            estream.indent(" " * description.length) do 
               form.display(estream)
            end
            
            estream.end_line()
         end
         
         accepted, length = scan( position, form, estream ) 
         
         #
         # We specifically refuse to accept 0-length matches at this level.  If something
         # is entirely optional, and matches with 0-length, it really isn't there.
         
         if accepted && length > 0 then
            solution = Solution.new( @source.slice(position, length), grammar_name, symbol_name ) 
            estream.indent { estream.puts "==> matched against [#{solution.to_s.escape}]" } if estream
         else
            estream.indent { estream.puts "==> didn't match" } if estream
         end
         
         return solution
      end






    #---------------------------------------------------------------------------------------------------------------------
    # Pattern handling
    #---------------------------------------------------------------------------------------------------------------------
    
    protected

      #
      # scan()
      #  - compares the supplied ExpressionForm/SparseRange against the source at the specified position
      #    and returns a flag indicating if it matches and a count of the number of characters it matches
      
      def scan( position, form, estream = nil )
         accepted = false
         length   = 0
         
         case form
            
            #
            # For a sequence, all elements must be accepted, in successive order.
         
            when Util::ExpressionForms::Sequence
               form.each_element do |element|
                  accepted, match_length = scan( position + length, element, estream )
                  break unless accepted
                  
                  length += match_length
               end
               
               
            #
            # For a repeater, loop.  We'll handle SparseRange directly, to improve
            # performance in that loop.
            
            when Util::ExpressionForms::Repeater
               range    = form.element.is_a?(Range) ? form.element : nil
               accepted = form.times() do |number, required|
                  if range then
                     break !required unless range.member?(@stream[position + length])
                     length += 1 
                  else
                     child_accepted, child_length = scan( position + length, form.element, estream )
                     break !required unless child_accepted
                     length += child_length
                  end
               end
               
            
            # 
            # For a branch, try all options and pick the longest.
            # BUG: is picking the longest match the right choice?
            
            when Util::ExpressionForms::BranchPoint
               form.each_element() do |element|
                  option_accepted, option_length = scan( position, element, estream )
                  if option_accepted then
                     accepted = true
                     length   = max( length, option_length )
                  end
               end
                              

            #
            # SparseRange is the meat of our work, and is also the simplest thing.
            
            when Util::SparseRange
               if form.member?(@source[position]) then
                  accepted = true
                  length   = 1
               end
         
         
            #
            # Anything else is a bug.
            
            else
               nyi( nil, form )
               
         end
         
         
         
         if accepted then
            return accepted, length
         else
            return false, 0
         end
      end
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Internal Data Structures
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      class Solution
         def initialize( character_string, grammar_name, symbol_name )
            @character_string = character_string.to_a
            @grammar_name     = grammar_name
            @symbol_name      = symbol_name
         end
         
         def prepend( c )
            @character_string.unshift c
         end
         
         def append( c )
            @character_string.push c
         end
         
         def follow_position( position )
            return position + @character_string.length
         end
         
         def to_s()
            return @character_string.pack("U*")
         end
                  
         def to_Token( start_position, line_number, column_number, source )
            return Artifacts::Nodes::Token.new( self.to_s, @grammar_name, @symbol_name, start_position, line_number, column_number, source, false, start_position + @character_string.length )
         end
      end

   end # Lexer
   




end  # module Interpreter
end  # module Scanner
end  # module RCC





#
# If called directly, run a simple character-at-a-time lexer at user command.  Useful for testing basic lexer functionality.

if __FILE__ == $0 then
   
   class TestLexer < RCC::Interpreter::Lexer
      def lex( *ignored )
         return nil
      end
   end
   
   
   source = nil
   File.open(ARGV[0]) do |file|
      source = RCC::Interpreter::Source.new( file.read, nil )
   end
   
   if source then
      lexer = TestLexer.new( source )
      
      print "> "
      while line = STDIN.gets()
         command_tokens = line.chomp.split(/\s+/)
         begin
            case command_tokens[0]
               when nil, "lex"
                  (command_tokens.length < 2 ? 1 : command_tokens[1].to_i).times do |index|
                     token = lexer.next_token( nil, nil, "" )
                     puts "Lexed: #{token.description} at #{token.line_number}:#{token.column_number}, position #{token.start_position}"
                  end
               when "reset"
                  lexer.set_position( command_tokens[1].to_i )
               else
                  puts "unrecognized command; try: lex <number>; reset <position>"
            end
         rescue Exception => e
            puts "encountered an error [#{e.message}]"
            puts "   " + e.backtrace.join("\n   ")
         end
         print "\n> "
      end
   end
   
   
end
