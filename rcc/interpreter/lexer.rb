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
require "rcc/interpreter/token.rb"
require "rcc/interpreter/line_reader.rb"


module RCC
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
      
      def initialize( input, descriptor )
         @line_reader   = LineReader.new( input, descriptor )    # The input stream from which we'll draw input
         @descriptor    = descriptor                             # A descriptor of the input, used during Token production
                                                                 
         @pending_lines = []     # Lines ahead of the lex() point in the @input (or @text)
         @position      = 0      # The @line_reader position at the lex() point
         @line_number   = 1      # The current line number, at the lex() point
         @column_number = 1      # The current column number, at the lex() point
         @last_consumed = nil    # The last Token consumed() (used for updating line and column numbers)
      end
      
      
      
      #
      # input_remaining?() 
      #  - returns true if there is input still to be processed
      
      def input_remaining?()
         return true unless @pending_lines.empty?
         return update_position()
      end
      
      
      #
      # sample_unconsumed()
      #  - returns the some number of the unconsumed characters from the current line
      
      def sample_unconsumed( count = 40 )
         update_position()
         return @pending_lines[0].slice(0, count) unless @pending_lines.empty?
         return ""
      end
      

      #
      # next_token()
      #  - runs the lexer against the input until one token is produced or the input is exhausted
      
      def next_token( lexer_plan, explain = false )
         token = lex( lexer_plan, explain )
         
         if explain then
            if token.nil? then
               if input_remaining?() then
                  puts "===> ERROR LEXING: #{prep(@pending_lines[0])}"
               else
                  puts "===> DONE"
               end
            else
               puts "===> PRODUCING #{prep(token)} at #{token.line_number}:#{token.column_number}, position #{token.start_position}"
            end
         end
         
         return token
      end


      #
      # reset()
      #  - resets the position of the lexer
      
      def reset( to_position )
         @line_reader.seek( to_position )
         @pending_lines.clear()
         @last_consumed = nil
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
      
      def lex( state, explain, built = "" )
         token = nil   
         while token.nil? and input_remaining?()
            
            #
            # First, try to read by character lookahead.
            
            if c = la() then
               if state.child_states.member?(c) then
                  puts "     la() is #{prep(c)}, which matches a child state; recursing" if explain
                  token = lex( state.child_states[c], explain, built + consume() )
                  
               elsif state.accepted.member?(c) then
                  puts "     la() is #{prep(c)}, which is accepted by this state; producing #{built+c}" if explain
                  token = Token.new( built + consume() )
                  token.locate( @position, @line_number, @column_number, @descriptor )
                  
               end
            end

            if token.nil? and explain then
               if state.tail_processing.nil? or state.tail_processing.empty? then
                  puts "     la() is #{prep(c)}, which does not match this state"
               else
                  puts "     la() is #{prep(c)}, which does not match this state; attempting tail processing"
               end
            end
            
            #
            # If we got nothing, and we have tail_processing, try then in order until something
            # matches.
            
            if token.nil? and !state.tail_processing.nil? then
               state.tail_processing.each do |definition|
                  case definition
                  when Model::TerminalDefinitions::Pattern
                     if match = consume_match(definition.regexp) then
                        token = Token.new( match )
                        token.locate( @position, @line_number, @column_number, @descriptor, definition.name.intern )
                        puts "     matched #{definition.definition}" if explain
                        break
                     else
                        puts "     did not match #{definition.definition}" if explain
                     end
                  when Model::TerminalDefinitions::Special
                     nyi "special terminal definitions"
                  end
               end
            end
            
            #
            # If we got something, and it is on the ignore list, ignore it.  We'll then try again, unless
            # there is nothing more to do.
            
            if token.nil? then
               break
            else
               if !state.ignore_list.nil? and state.ignore_list.member?(token.type) then
                  puts "     IGNORING #{prep(token)}" if explain
                  token = nil
               end
            end
         end
         
         return token
      end
      
      
      #
      # la()
      #  - looks ahead one or more characters
      #  - reads write through line boundaries, if necessary
      
      def la( count = 1 )
         c = nil
         
         if update_position() then
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
      #  - shifts the next character off the lookahead and returns it
      
      def consume()
         c = nil
         if c = la() then 
            @last_consumed = @pending_lines[0].slice!(0, 1)
         end
         
         return c
      end


      #
      # consume_match()
      #  - applies a Regexp to the unconsumed portion of the current line
      #  - if a match occurs, consumes those characters and returns them
      #  - matches must be wholly contained within the current line
      
      def consume_match( regexp )
         match = nil
         
         if update_position() then
            if @pending_lines[0] =~ regexp and $`.length == 0 then
               match = @pending_lines[0].slice!(0, $&.length)
               @last_consumed = match
            end
         end
         
         return match
      end
      
      
      #
      # update_position()
      #  - ensures the line buffer is full and adjusts the position markers to account for the last data consumed 
      #    (if not already done)

      def update_position()
         unless @last_consumed.nil?
            @position += @last_consumed.length
            
            if @pending_lines[0].empty? then
               @pending_lines.shift
               @column_number = 1
               @line_number  += 1
            else
               @column_number += @last_consumed.length
            end

            @last_consumed = nil
         end

         if @pending_lines.empty?() then
            read_ahead() or return false
         end

         return true
      end
      
      
      #
      # read_ahead( lines = 1 )
      #  - reads the next line from the input until a certain number of lines are in the buffer
      
      def read_ahead( lines = 1 )
         if @pending_lines.empty? then
            @position      = @line_reader.position
            @line_number   = @line_reader.line_number
            @column_number = @line_reader.column_number
         end
            
         while @pending_lines.length < lines
            if line = @line_reader.gets then
               @pending_lines << line
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
         return "[#{data.gsub("\n", "\\n")}]"
      end
      
      
   end # Lexer
   




end  # module Interpreter
end  # module Rethink





#
# If called directly, run a simple character-at-a-time lexer at user command.  Useful for testing basic lexer functionality.

if __FILE__ == $0 then
   
   class TestLexer < RCC::Interpreter::Lexer
      def lex( *ignored )
         token = nil   

         if c = la() then
            token = RCC::Interpreter::Token.new( consume() )
            token.locate( @position, @line_number, @column_number, @descriptor )
         end

         return token
      end
   end
   
   
   
   File.open(ARGV[0]) do |file|
      lexer = TestLexer.new( file, nil )
      
      print "> "
      while line = STDIN.gets()
         command_tokens = line.chomp.split(/\s+/)
         begin
            case command_tokens[0]
               when nil, "lex"
                  (command_tokens.length < 2 ? 1 : command_tokens[1].to_i).times do |index|
                     lexed = lexer.next_token( nil, true )
                  end
               when "reset"
                  lexer.reset( command_tokens[1].to_i )
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