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
 #  - processes Lexical actions in a (hopefully) more efficient manner than the Parser can

   class Lexer
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and public interface
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( source )
         @source = source       # The Source from where we will draw our input
      end
      
      
      #
      # read()
      #  - reads a single Token from the source, starting at the specified position, using
      #    the supplied LexerPlan
      #  - returns Token::end_of_file on the end of input
      
      def read( start_position )
         pos = start_position.adjusted_stream_position
         line_number = column_number = 0

         if @source.at_eof?(stream_position) then
            line_number   = @source.eof_line_number
            column_number = @source.eof_column_number
         else
            line_number   = @source.line_number(stream_position)
            column_number = @source.column_number(stream_position)
         end
         
         characters = []
         states     = [ start_position.state ]

         forever do
            c      = readc(pos)
            action = states[-1].action_for( c )
            
            case action
               
               #
               # Read a single character and prepare to move on.
               
               when Plan::Actions::Read
                  characters << c
                  states     << action.to_state
                  pos   += 1
                  
               
               #
               # Group several characters for further processing.  Unlike in the Parser, we
               # perform the Shift here directly.  We don't move the pos, because nothing was
               # used.
               
               when Plan::Actions::Group
                  length = action.by_production.length
                  group  = characters.slice!(-length..-1)
                  states.slice!(-length..-1)
                  states << states[-1].action_for(action.by_production.name).to_state
                  characters << group


               #
               # Tokenize ends the read() operation.  We set our answer into the start_position
               # and return.
               
               when Plan::Actions::Tokenize
                  length = action.by_production.length
                  if characters.length == length then
                     start_position.determinant = Nodes::Token.new( characters.flatten, action.by_production.name, start_position.adjusted_stream_position, line_number, column_number, @source )
                     break
                  else
                     nyi( "error handling for too short Tokenize" )
                  end
                  
                  
               #
               # For lexical stuff, all Attempt actions will be of the same type.  For Group
               # actions, we want the longest match (always), so we need to try all branches
               # and find the longest Token produced.  For Tokenize, we need to interact with
               # the Parser's BranchInfo system.
               
               when Plan::Actions::Attempt
                  case action.actions[0]
                  when Plan::Actions::Group
                     nyi()
                  when Plan::Actions::Tokenize
                     nyi()
                  else
                     nyi( "attempt support for #{action.actions[0].class.name}" )
                  end
               
               
               #
               # If there is no action, we've got an error.
               
               when NilClass
                  nyi( "error" )
                  
               else
                  nyi( "not supported", action )
            end
         end
      end
      
      
      
      #
      # readc()
      
      def readc(at)
         return -1 if @source.at_eof?(at)
         return @source[at]
      end
      

   end # Lexer
   




end  # module Interpreter
end  # module Scanner
end  # module RCC


