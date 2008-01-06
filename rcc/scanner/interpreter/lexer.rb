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

      attr_reader :line_number
      attr_reader :column_number
      attr_reader :position
      
      def initialize( source )
         @source        = source        # The Source from where we will draw our input
         @position      = 0             # The position within @source of the next unconsumed character
         @pending_lines = []            # The working set of lines from @source starting at @position
         @pending_chars = 0             # The number of characters in @pending_lines
         @line_number   = 1             # The current line number, at the lex() point
         @column_number = 1             # The current column number, at the lex() point
         @last_consumed = nil           # The last String consumed() (used for updating line and column numbers)
      end
      
      
      #
      # locate_token()
      #  - sets a Token's position to the current position
      
      def locate_token( token, type_override = nil )
         return token.locate( @position, @line_number, @column_number, @source, type_override, nil )
      end
      
      
      #
      # input_remaining?() 
      #  - returns true if there is input still to be processed
      
      def input_remaining?( position = nil )
         set_position( position )
         return @position < @source.length
      end
      
      
      #
      # sample()
      #  - returns the some number of the characters from a line starting at position
      
      def sample( position, count = 40 )
         return @source.line_from( position ).to_s.slice( 0, count ) 
      end
      

      #
      # next_token()
      #  - runs the lexer against the input until one token is produced or the input is exhausted
      #  - returns a Token::end_of_file token on the end of input
      
      def next_token( position, lexer_plan, explain_indent = nil )
         token = lex( position, lexer_plan, explain_indent )
         
         unless explain_indent.nil?
            if token.nil? then
               if input_remaining?() then
                  puts "#{explain_indent}===> ERROR LEXING: #{prep(@pending_lines[0])}; will PRODUCE one-character token of unknown type"
               else
                  puts "#{explain_indent}===> DONE"
               end
            else
               puts "#{explain_indent}===> PRODUCING #{token.description} at #{token.line_number}:#{token.column_number}, position #{token.start_position}"
            end
         end
         
         if token.nil? then
            if input_remaining?() then
               return locate_token( Artifacts::Token.new(consume()), false )
            else
               return Artifacts::Token.end_of_file( @position, @line_number, @column_number, @descriptor )
            end
         else
            return token
         end
      end


      #
      # set_position()
      #  - sets the position of the lexer
      #  - returns true if you got the data you asked for
      
      def set_position( to_position, lines = 1 )
         if to_position.nil? then
            if @last_consumed.nil? then
               to_position = @position
            else
               to_position = @position + @last_consumed.length
            end
         end
         
         @last_consumed = nil
         offset = to_position - @position
      
         #
         # If the data is already in @pending_lines, we just need to adjust our current data.
         
         if offset >= 0 and offset < @pending_chars then
            
            #
            # Get to the right line.

            while offset >= @pending_lines[0].length
               retiring_chars  = @pending_lines[0].length
               offset         -= retiring_chars
               @pending_chars -= retiring_chars
               @position      += retiring_chars
               @line_number   += 1
               @column_number  = 1
               @pending_lines.shift
            end
            
            #
            # Get to the right character in the line.
            
            if offset > 0 then
               @pending_lines[0].slice!( 0, offset )
               @position      += offset
               @column_number += offset
               @pending_chars -= offset
            end
            
         #
         # Otherwise, we'll need to reload from the Source.
         
         else
            @pending_lines.clear
            @pending_chars = 0
            @position      = to_position
            
            if @position >= @source.length then
               @line_number   = nil
               @column_number = nil
            else
               line_index = @source.line_index( to_position )
               if line_fragment = @source.line_from(to_position, line_index) then
                  @pending_lines << line_fragment
                  @pending_chars += line_fragment.length
                  @line_number    = line_index + 1
                  @column_number  = @source.column_index( to_position, line_index ) + 1
               end
            end
         end
         
         #
         # Read additional lines, as required.

         read_ahead( lines ) if lines > @pending_lines.length

         return @pending_lines.length == lines
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Token production
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
      
      #
      # lex()
      #  - run a LexerPlan against the input
      #  - returns a single token relevant to the supplied state
      #  - always takes the longest match possible
      #  - pass nil for position to pick up where you left off
      
      def lex( position, lexer_plan, explain_indent )
         set_position( position )
         
         token = nil   
         while token.nil? and input_remaining?()

            #
            # First, try to lex a literal token.
            
            token = lex_literal( lexer_plan.literal_processor, explain_indent )


            #
            # Next, try pattern matching.
            
            if token.nil? and !la().nil? then
               if lexer_plan.patterns.empty? then
                  puts "#{explain_indent}     there are no pattern matching options in this state" unless explain_indent.nil?
               else
                  puts "#{explain_indent}     attempting pattern matches:" unless explain_indent.nil?
                  lexer_plan.patterns.each do |pattern, symbol_name|
                     if match = consume_match(pattern) then
                        token = locate_token( Artifacts::Token.new(match), symbol_name )
                        puts "#{explain_indent}     matched #{symbol_name}" unless explain_indent.nil?
                        break
                     else
                        puts "#{explain_indent}     did not match #{symbol_name}" unless explain_indent.nil?
                     end
                  end
               end
            end
            
            
            #
            # Finally, try tail processing, if available.
            
            if token.nil? and !la().nil? then
               if lexer_plan.fallback_plan.nil? then
                  puts "#{explain_indent}     there is no fallback plan for this lexer" unless explain_indent.nil?
               else
                  puts "#{explain_indent}     attempting fallback plan" unless explain_indent.nil?
                  token = lex( position, lexer_plan.fallback_plan, explain_indent )
               end
            end

            
            #
            # If we got something, and it is on the ignore list, ignore it.  We'll then try again, unless
            # there is nothing more to do.  
            
            if token.nil? then
               break
            else
               if !lexer_plan.ignore_list.nil? and lexer_plan.ignore_list.member?(token.type) then
                  puts "#{explain_indent}===> IGNORING #{prep(token)}" unless explain_indent.nil?
                  token = nil
               end
            end
         end
         
         return token
      end
      
      
      #
      # lex_literal()
      #  - processes a LexerState against the current lookahead
      
      def lex_literal( state, explain_indent = nil, base_la = 1 )
         token = nil
         
         #
         # First, try to read by character lookahead.  Note that for "+" and "++", "+" will match both
         # a child_plan and an accepted entry.  So we try the child_plan first.  If it fails, we'll try
         # accept instead.  In other words, we take the longest match we can.  
         
         if c = la(base_la) then
            if state.child_states.member?(c) then
               puts "#{explain_indent}     la(#{base_la}) is #{prep(c)}, which matches a child state; recursing" unless explain_indent.nil?
               token = lex_literal( state.child_states[c], explain_indent, base_la + 1 )
            end
      
            if token.nil? and state.accepted.member?(c) then
               puts "#{explain_indent}     la(#{base_la}) is #{prep(c)}, which is accepted by this state; producing type #{state.accepted[c]}" unless explain_indent.nil?
               token = locate_token( Artifacts::Token.new(consume(base_la)), state.accepted[c] )
            end
         end

         if token.nil? and !c.nil? then
            puts "#{explain_indent}     la(#{base_la}) is #{prep(c)}, which does not match any literal options in this state" unless explain_indent.nil?
         end
         
         return token
      end
            
      
      #
      # la()
      #  - looks ahead one or more characters
      #  - reads write through line boundaries, if necessary
      
      def la( count = 1 )
         c = nil
         
         if set_position(nil) then
            line = 0
            while c.nil?
               if count <= @pending_lines[line].length then
                  c = @pending_lines[line].slice(count-1, 1)
               else
                  line += 1
                  read_ahead( line ) or break
               end
            end
         end
         
         return c
      end
      
      
      #
      # consume()
      #  - shifts some number of characters off the lookahead and returns it
      
      def consume( count = 1 )
         c = nil
         
         if c = la(count) then 
            @last_consumed = @pending_lines[0].slice(0, count)
         end
         
         return @last_consumed
      end


      #
      # consume_match()
      #  - applies a Regexp to the unconsumed portion of the current line
      #  - if a match occurs, consumes those characters and returns them
      #  - matches must be wholly contained within the current line
      
      def consume_match( regexp )
         match = nil
         
         if set_position(nil) then
            if @pending_lines[0] =~ regexp and $`.length == 0 then
               match = @pending_lines[0].slice(0, $&.length)
               @last_consumed = match
            end
         end
         
         return match
      end

      
      #
      # read_ahead( lines = 1 )
      #  - reads additional lines from the input
      
      def read_ahead( lines = 1 )
         (lines - @pending_lines.length).times do |i|
            if !@line_number.nil? and line = @source.line( @line_number - 1, true ) then
               @pending_lines << line
               @pending_chars += line.length
            else
               return false
            end
         end
         
         return true
      end
   
      
      # 
      # prep()
      #  - formats a String/Token for explain output
      
      def prep( data )
         return "<end of input>" if data.nil?
         return "[#{data.gsub("\n", "\\n")}]"
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