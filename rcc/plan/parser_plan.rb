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

module RCC
module Plan

 
 #============================================================================================================================
 # class ParserPlan
 #  - a plan for a backtracking LALR(1) parser that implements a Model::Grammar
 #  - whereas the Model Grammar deals in Rules and Forms, we deal in Productions; we both deal in Symbols

   class ParserPlan
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :master_plan       # The MasterPlan
      attr_reader :name              # The name of the Grammar from which this Plan was built
      attr_reader :lexer_plan        # A LexerState that describes how to lex the Grammar; note that each State can produce a customization on this one
      attr_reader :state_table       # Our States, in convenient table form
      attr_reader :ast_classes       # Our ASTClasses, in declaration order

      def initialize( master_plan, name, state_table, enable_backtracking = false )         
         @master_plan         = master_plan
         @name                = name
         @state_table         = state_table
         @lexer_plan          = master_plan.get_lexer_plan( name )
         @ast_classes         = master_plan.get_ast_plan( name )
         @enable_backtracking = enable_backtracking
      end
      
      
      def non_terminal?( type )
         return false unless type.is_a?(::Symbol)
         return @production_sets.member?(type)
      end
      
      def non_terminals()
         return @production_sets.keys
      end
      
      
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Parser construction
    #---------------------------------------------------------------------------------------------------------------------


      #
      # compile_actions()
      #  - runs through all our State tables and builds Actions that can drive a compiler
      #  - optionally constructs explanations for conflict resolutions
      
      def compile_actions( explain = false, k_limit = 1 )
         duration = Time.measure do 
            @state_table.each do |state|
               duration = Time.measure do
                  state.compile_actions( k_limit, @enable_backtracking, explain )
                  state.compile_customized_lexer_plan( @lexer_plan )
               end
               
               STDERR.puts "Action compilation for state #{state.number}: #{duration}s" if $show_statistics and duration > 0.25
            end
         end
         
         STDERR.puts "Action compilation duration: #{duration}s" if $show_statistics
         
         return self
      end



    

   
   
   
   
   
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "Grammar #{@name}"
      end
      
      def display( stream ) # BUG: pass via ContextStream: complete = true, show_context = :reduce_determinants )
         stream << "States\n"
         stream.indent do 
            @state_table.each do |state|
               state.display( stream )
            end
         end
      end
      
   



      
   end # Grammar
   


end  # module Model
end  # module RCC




# This code is garbage (unfinished finished), but might come in useful again.  Stored here for now.
#
#
# first_and_follow_sets()
#  - returns a hash, mapping potential first terminals to all potential follow phrases for this rule
#  - don't call this before all Forms have been added
#  - NOTE: during analysis, any child calls my have no choice but to produce output that includes non-terminal
#    firsts; this should never be the case for the outer-most call
#
# def first_and_follow_sets( loop_detector = nil )
#    return @first_and_follow_sets unless @first_and_follow_sets.nil?
#    loop_detector = Util::RecursionLoopDetector.new() if loop_detector.nil?
#    
#    #
#    # Calculate the first and follows sets.  Any Phrase that begins with a Terminal is our friend.
#    # Any Phrase that begins with a NonTerminal will require a lot more work.
#    
#    first_and_follow_sets = {}
#    complete = loop_detector.monitor(self.object_id) do
# 
#       follow_by_terminal_firsts     = {}
#       follow_by_non_terminal_firsts = {}
#       
#       #
#       # Go through all the Phrases in our Forms and sort them.  Terminal-led Phrases go straight into our finished
#       # set.  NonTerminal-lead Phrases go in follow_by_non_terminal_firsts for further processing.
#       
#       @forms.each do |form|
#          form.phrases.each do |phrase|
#             next if phrase.length <= 0
#             
#             first  = phrase.symbol[0]
#             follow = phrase.slice(1..-1)
#             
#             set = first.terminal? ? follow_by_terminal_firsts : follow_by_non_terminal_firsts
#             set[first] = [] unless set.member?(first)
#             set[first] << follow
#          end
#       end
#       
#       #
#       # Next, we expand the NonTerminal firsts and produce the remainder of the first_and_follow_sets.  Any
#       # that start with our NonTerminal get deferred until the very end.
#       
#       follow_by_non_terminal_firsts.keys.each do |non_terminal|
#          next if non_terminal.name == @name
#          nyi( "error handling for missing non-terminals" ) unless @grammar.rules.member?(non_terminal)
#          
#          #
#          # Recurse to get the additional first and follow sets.  Any that return nil indicate that we tried to
#          # expand something further up the call chain, so we let it worry about those expansions.  If the first
#          # is a non-terminal, it is either ours, or something we can't expand due to a recursion loops.  In the
#          # latter case, we'll have to return it with the rest.
# 
#          child_first_and_follow_sets = @grammar.rules[rule_name].first_and_follow_sets( loop_detector )
#          unless child_first_and_follow_sets.nil? 
#             child_first_and_follow_sets.each do |first, follow_sets|
#                if first.terminal? then
#                   follow_by_terminal_firsts.array_set( first, PhraseJoin.new(follow_sets, follow_by_non_terminal_firsts[non_terminal]) )
#                elsif first.name == @name then
#                   follow_by_non_terminal_firsts[first] = [] unless follow_by_non_terminal_firsts.member?(first)
#                   follow_by_non_terminal_firsts.concat( follow_sets )
#                else
#                   follow_by_terminal_firsts[first] = [] unless follow_by_non_terminal_firsts.member?(first)
#                   bug( "why are we getting foreign non-terminals from our ") 
#                   
#                end
#                      
#                   
#             end
#          
#          # 
#          # We that done, every child_first_and_follow_set should begin with on of two things: a Terminal,
#          # or a NonTerminal that refers to us.
#          
#       end
#       
#    end
# 
#    #
#    # If we just looped, return nil.  Our earlier invokation will deal with it.  If the result we just
#    # calculated is complete, cache it for reuse.
#    
#    if complete.nil?
#       return nil
#    else
#       @first_and_follow_sets = first_and_follow_sets if complete
#       return first_and_follow_sets
#    end
# end
# 
# 
# 
