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
require "#{$RCCLIB}/interpreter/token_stream.rb"
require "#{$RCCLIB}/interpreter/situation.rb"
require "#{$RCCLIB}/interpreter/failure.rb"
require "#{$RCCLIB}/interpreter/csn.rb"
require "#{$RCCLIB}/interpreter/asn.rb"


module RCC
module Interpreter

 
 #============================================================================================================================
 # class Parser
 #  - an interpretive Parser for a Grammar
 #  - useful for testing stuff out

   class Parser
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      #
      # initialize()
      #  - initializes this Parser for use
      #  - repair_search_tolerance is used to limit recursion in discover_repair_options()
      
      def initialize( parser_plan, token_stream, build_ast = true )
         @parser_plan     = parser_plan
         @build_ast       = build_ast
         @start_situation = Situation.new( token_stream, @parser_plan.state_table[0] )
      end
            

      #
      # parse()
      #  - applies the Grammar to the inputs and builds a generic AST
      #  - returns the true if the parse succeeded
      #  - situation is optional -- skip it if you aren't passing one
      
      def parse( situation = nil, explain = true, indent = "" )
         
         situation = @start_situation if situation.nil?
         
         #
         # Process actions until a solution is found.

         until situation.accepted? or situation.failed?
            
            #
            # Get the state and lookahead.
            
            state, next_token, token_type = situation.look_ahead( nil, explain, indent )
            situation.display( indent, state, next_token ) if explain

            #
            # Select the next action.
            
            action = state.actions[token_type]
            
            if explain then
               STDOUT.puts "#{indent}| #{state.lookahead_explanations}"
               STDOUT.puts "#{indent}| Action analysis for lookahead #{Token.description(next_token)}"

               if state.explanations.nil? then
                  bug( "no explanations found" )
               else
                  state.explanations[token_type].each do |explanation|
                     explanation.to_s.split("\n").each do |line|
                        STDOUT << "#{indent}|    " << line.to_s << "\n"
                     end
                  end
               end
            end
                        
            #
            # If there is no action, we have an error.  We'll try to recover.  Otherwise, we process the action.

            if !action.nil? then
               perform_action( action, situation, next_token, token_type, explain, indent )
            else
               if explain then
                  STDOUT.puts "#{indent}===> ERROR DETECTED: cannot use #{next_token.description}"
                  indent += "   "
               end

               situation.token_stream.rewind( next_token )
               situation.failure = Failure.new( next_token, state.actions.keys.collect{|t| situation.token_stream.fake_token(t)} )
            end
         end
         
         return situation.accepted?
      end
      


      #
      # drive()
      #  - parse() stops at the first error; if this is what you need, call it directly
      #  - drive() drives the parse() through error corrections as far as it can go
      
      def drive( explain = true, indent = "" )
         return true if parse( @situation, explain, indent )
         
         corrections_queue = [] + find_error_corrections( @situation, explain, indent )
         until corrections_queue.empty?
            correction = corrections_queue.shift
            if correction.apply(self, explain, indent) then
               correction.
               # yay!  what now?
            else
               find_error_corrections( correction.situation, explain, indent ).reverse.each do |child_correction|
                  corrections_queue.unshift( child_correction )
               end
            end
         end
         
               
               
            
            if parse(situation, explain, indent) then
               # yay!  what now?
            else
               situation.pending_corrections.each do |correction|
                  
               end
            end
            
         end
         
         
         
         
         
         #
         # So, we now have a list of corrected parses that completed.  We must now pick the ones to report to the 
         # user.  Presumably, errors are not intentional, so they shouldn't be too frequent.  We'll therefore pick 
         # those solutions that have the fewest errors.  For now, if there's more than one choice, we'll let the 
         # user sort it out.

         if accepted_corrections.empty? then
            situation.corrections << failure
         else
            accepted_corrections.sort!{ |a, b| a.situation.corrections.length <=> b.situation.corrections.length }

            fewest_errors         = accepted_corrections[0].situation.correction.length
            @corrections          = accepted_corrections.select{ |c| c.situation.corrections.length == fewest_errors }
         end
         
         
         
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Mid-level Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    protected

      
      #
      # perform_action()
      #  - performs a single action against the current Parser state
      
      def perform_action( action, situation, next_token, token_type, explain, indent )
         case action
            when Plan::Actions::Shift
               situation.shift( situation.token_stream.consume(), action.to_state, explain, indent )
               
            when Plan::Actions::Reduce
               raise InvalidReduce.new() unless situation.reduce(action.by_production, @build_ast, explain, indent)
               
            when Plan::Actions::Accept
               situation.accept( explain, indent )
               
            when Plan::Actions::Attempt
               first = true
               child_indent = "#{indent}   "
               
               rewind_to_token = next_token
               action.actions.each do |attempt_action|
                  if explain then
                     if first then
                        first = false
                     else
                        STDOUT.puts "#{indent}" 
                        STDOUT.puts "#{indent}" 
                        STDOUT.puts "#{indent}<=== RETURN"
                     end

                     STDOUT.puts "#{indent}" 
                     STDOUT.puts "#{indent}" 
                     situation.display( indent ) if explain
                     STDOUT.puts "#{indent}===> ATTEMPT #{attempt_action.to_s}"
                  end

                  begin
                     
                     #
                     # Set up for our attempt and feed in the selected action.
                     
                     attempt_situation = situation.cover_for_attempt( attempt_action.is_a?(Plan::Actions::Shift) ? attempt_action.valid_productions : nil )
                     perform_action( attempt_action, attempt_situation, next_token, token_type, explain, child_indent ) 
                     
                     #
                     # Recurse with the new Situation and see what happens.
                     
                     if parse( attempt_situation, explain, child_indent ) then
                        situation.take_solution_from( attempt_situation )
                        break
                     else
                        situation.rewind( next_token )
                     end
                  rescue InvalidReduce
                     situation.rewind( next_token )
                  end
               end
            
            else
               nyi "support for #{action.class.name}"
         end
      end







    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
    
      #
      # find_error_corrections()
      #  - looks for and constructs Corrections for the error in the supplied Situation
      #  - BEWARE: the supplied Situation will unwound (by unwind()) in the process
      
      def find_error_corrections( situation, explain, indent )
         
         corrections = []
         
         #
         # Start by looking for a way around the error.  We can insert a token, replace a token, or delete a token,
         # and we can do it at the current lexer situation or AT ANY point on the state stack.  This allows us to
         # correct errors that we didn't notice until we were past them, without opening up the entire token stream
         # for correction analysis.  Our caller (generally drive()) will restart the parse in each Correction we
         # produce.  Any child parse that succeeds is in the running for error reporting.
         
         accepted_corrections = []
         situation.unwind do |state|
            state, next_token, token_type = situation.look_ahead()
            situation.rewind( next_token )

            failed_action = state.actions[token_type]
            symbols       = state.actions.keys
            symbols.each do |leader_type|
               next if leader_type == token_type
               action = state.actions[leader_type]
               
               situation.rewind( next_token )
               fake_token = situation.token_stream.fake_token( leader_type )

               #
               # Option 1: before next_token, insert valid tokens and see if it changes anything
               
               if correction_worth_trying?( situation, action, failed_action, fake_token ) then
                  corrections << situation.correct( fake_token, nil )
               end

               #
               # Option 2: replace next_token with one of our known valid alternatives, provided the replacement 
               # is similar to what the user actually wrote.
               
               situation.token_stream.rewind( next_token )
               if next_token.similar_to?(leader_type) then
                  if correction_worth_trying?( situation, action, failed_action, fake_token )
                     corrections << situation.correct( fake_token, next_token )
                  end
               end
            end


            #
            # Option 3: delete next_token and try the one following.
            
            situation.token_stream.rewind( next_token )
            if state.actions.member?(situation.token_stream.la(2).type) then 
               correctsion << situation.correct( nil, consume() )
            end
         end
         
         return corrections
      end
      
      
      #
      # correction_worth_trying?()
      #  - returns true if the specified lookahead is worth trying as an error correction
      #  - reads the follow token in the appropriate state, so you'll need to reset the Situation when done
      
      def correction_worth_trying?( situation, action, failed_action, inserted_token )
         worth_trying = false
         
         case action
            when Plan::Actions::Shift
               to_state = action.to_state
               worth_trying = true if action.to_state.actions.member?(situation.la(1, action.to_state).type) 

            when Plan::Actions::Reduce
               unless failed_action.is_a?(Plan::Actions::Reduce) and failed_action.by_production == action.by_production
                  production    = action.by_production
                  count         = production.symbols.length
                  new_top_state = situation.state_stack[-(count+1)]

                  if new_top_state.transitions.member?(production.name) then
                     goto_state = new_top_state.transitions[production.name]
                     if goto_state.actions.member?(inserted_token.type) then
                        worth_trying = correction_worth_trying?( situation, goto_state.actions[inserted_token.type], failed_action, inserted_token )
                     end
                  end
               end

            when Plan::Actions::Accept
               worth_trying if follow_type.type == nil
               
            when Plan::Actions::Goto
               # no op -- these are handled by Reduce

            when Plan::Actions::Attempt
               action.actions.each do |attempt_type, attempt_action|
                  case attempt_action
                     when Plan::Actions::Shift
                        worth_trying = true if attempt_action.to_state.actions.member?(situation.la(1, attempt_action.to_state).type) 

                     when Plan::Actions::Reduce
                        unless failed_action.is_a?(Plan::Actions::Reduce) and failed_action.by_production == attempt_action.by_production
                           production    = attempt_action.by_production
                           count         = production.symbols.length
                           new_top_state = situation.state_stack[-(count+1)]

                           if new_top_state.transitions.member?(production.name) then
                              goto_state    = new_top_state.transitions[production.name]
                              if goto_state.actions.member?(inserted_token.type) then
                                 worth_trying = correction_worth_trying?( situation, goto_state.actions[inserted_token.type], failed_action, inserted_token )
                              end
                           end
                        end
                  end
               end
               worth_trying = true

            else
               nyi "support for #{action.class.name}"
         end
         
         return worth_trying
      end
      

      #
      # DISCARDED in favour of new strategy.   To be deleted after SVN commit.
      # #
      # # discover_repair_insertions()
      # #  - searches for repair options in the current and successive states (by recursion)
      # #  - a repair option must move the parse forward at least one real token to be worth trying
      # #  - recursion depth is limited by @repair_search_tolerance
      # #  - adds RepairAttempt objects to @repair_attempts
      #       
      # def discover_repair_insertions( state, situation, next_token_type, breadcrumbs = [] )
      #    
      #    #
      #    # We will check each action for a result that will get the parse moving forward again.  If we find one,
      #    # we add it to the list.  If we don't, and we haven't reached our tolerance, we try another insertion.
      #    
      #    state.actions.each do |insertion_type, action|
      #       discovered = false
      #       next_state = nil
      #       
      #       case action
      #          when Plan::Actions::Shift
      #             process_repair_insertion( action.to_state, insertion_type, next_token_type, breadcrumbs )
      #          
      #          when Plan::Actions::Reduce
      #             production    = action.by_production
      #             count         = production.symbols.length
      #             new_top_state = @state_stack[-(count+1)]
      #             goto_state    = new_top_state.transitions[production.name]
      # 
      #             process_repair_insertion( goto_state, insertion_type, next_token_type, breadcrumbs )
      #             
      #          when Plan::Actions::Accept
      #             # we can't accept while we have pending lookahead
      #          
      #          when Plan::Actions::Attempt
      #             action.actions.each do |attempt_action|
      #                case attempt_action
      #                   when Plan::Actions::Shift
      #                      process_repair_insertion( action.to_state, insertion_type, next_token_type, breadcrumbs )
      # 
      #                   when Plan::Actions::Reduce
      #                      production    = action.by_production
      #                      count         = production.symbols.length
      #                      new_top_state = @state_stack[-(count+1)]
      #                      goto_state    = new_top_state.transitions[production.name]
      # 
      #                      process_repair_insertion( goto_state, insertion_type, next_token_type, breadcrumbs )
      #                   else
      #                      nyi "support for #{action.class.name}"
      #                end
      #             end
      #       
      #          else
      #             nyi "support for #{action.class.name}"
      #       end
      #    end
      #    
      #    return done
      # end
      # 
      # 
      # #
      # # process_repair_insertion()
      # #  - helper for discover_repair_insertions() that either builds a RepairAttempt or recurses back into 
      # #    discover_repair_insertions()
      # #  - recursion is limited by @repair_search_tolerance
      # 
      # def process_repair_insertion( next_state, situation, insertion_type, next_token_type, breadcrumbs )
      #    if next_state.actions.member?(next_token_type) then
      #       @repair_insertions << breadcrumbs
      #    else
      #       unless breadcrumbs.length >= @repair_search_tolerance
      #          discover_repair_insertions( next_state, next_token_type, breadcrumbs + [insertion_type] )
      #       end
      #    end
      # end





    #---------------------------------------------------------------------------------------------------------------------
    # Error Classes
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      class ParserFailure < ::Exception
      end
      
      class InvalidReduce < ParserFailure
      end
      
      class UnableToRepair < ParserFailure
      end
      
      
      
    
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Low-level Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
    
      #
      # rewind()
      #  - rewinds the lexer to where it was when it produced the specified token
      
      def rewind( before_token )
         @token_stream.rewind( before_token )
      end
      
      
      #
      # set_lexer_plan()
      #  - swaps in a new LexerPlan for use with la() and consume()
      #  - takes the appropriate action to ensure the next token is from that new plan
      #  - doesn't do unecessary work
      
      def set_lexer_plan( plan )
         @token_stream.lexer_plan = plan
      end
    
          
      #
      # la()
      #  - looks ahead one or more tokens
      
      def la( count = 1, explain = false, indent = "" )
         return @token_stream.la( count, explain, indent )
      end
      
      
      #
      # consume()
      #  - shifts the next token off the lookahead and returns it
      
      def consume( explain = false, indent = "" )
         return @token_stream.consume( explain, indent )
      end
      
      
      
   end # Parser
   
   
   
   


end  # module Interpreter
end  # module Rethink
