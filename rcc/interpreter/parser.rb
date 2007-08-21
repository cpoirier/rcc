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
require "#{$RCCLIB}/interpreter/error.rb"
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
      # go()
      #  - go() drives the parse() through error corrections as far as it can go
      
      def go( explain_indent = nil )
         attempt_queue    = [@start_situation]
         correction_queue = []
         recovery_queue   = []
         pending_queue    = []
         in_recovery      = false
         error_limit      = 1000000000
         
         
         #
         # We proceed in steps, parsing through attempts first, then error corrections, and back again.  We are 
         # done immediately if we find an error-free, complete parse.  Error correction may encounter new Attempt
         # actions, which we will defer until all error corrections have been processed.  We'll then return to
         # the first phase and continue those error corrections.  
         #
         # This architecture allows us to avoid stack overflows from deep recursion, and also allows us to set a 
         # time limit on error correction.  And a natural side effect is that errors earlier in the file will 
         # tend to be fully explored before ones later in the file.  Which is generally the way the user will 
         # want it.
         
         start_time = Time.now()
         until attempt_queue.empty? and recovery_queue.empty? and correction_queue.empty? or Time.now() - start_time > 3
            
            #
            # First, run the parse.  On an Attempt action, perform_action() will generate a list of Situations to
            # try, attach them to the context Situation, and throw a AttemptsPending exception.  We catch it and
            # reverse the Situations onto our attempt_queue.  By inserting them in reverse order at the front of
            # the queue, we maintain depth-first ordering we want.
            
            until attempt_queue.empty?
               attempt = attempt_queue.shift
               
               begin
                  if parse( attempt, explain_indent ) then
                     if in_recovery then
                        # what here?
                     else
                        return attempt.solution
                     end
                  else
                     recovery_queue << attempt
                  end
                  
               rescue InvalidReduce
                  attempt.discard()
               rescue AttemptsPending
                  attempt.attempts.reverse.each do |child_attempt|
                     attempt_queue.unshift child_attempt
                  end
               end
            end
            
            
            #
            # If we are still here, it is time to start error recovery.  For each recover_queue Situation, we'll
            # want to look for and apply Corrections (and resultant Corrections) in depth-first order.  When we
            # encounter an AttemptsPending exception, we'll add that work back to the attempt_queue and pick it
            # up on the next pass.
            
            in_recovery = true
            correction_queue.concat pending_queue
            pending_queue.clear
            
            until correction_queue.empty? and recovery_queue.empty?
               
               if correction_queue.empty? then
                  error_situation = recovery_queue.shift
                  correction_queue.concat find_error_corrections( error_situation, explain_indent )
               end
                  
               until correction_queue.empty?
                  correction = correction_queue.shift
         
                  #
                  # If the correction succeeds, we mark it as accepted.  This is automatically send up the chain of 
                  # Situations by the Correction and Situation code.
         
                  begin
                     if correction.apply(self, explain_indent) then
                        correction.accept()
                        error_limit = min( correction.situation.error_count, error_limit )
            
                     #
                     # Otherwise, we look for correction options for the failed correction.  If we find some, we add
                     # them to the work_queue and the current Correction's situation (to maintain the chain).  If there
                     # are no corrections to attempt, we discard the correction.  Again, this is automatically sent up 
                     # the chain, closing off dead branches of the correction tree.
         
                     else

                        #
                        # When we are done here, the next step will be to pick those branches of the correction tree that
                        # have the fewest errors.  Therefore, we can save work by cutting off any branch that already 
                        # has more errors than the best solutions we've already found.  This optimization can save a 
                        # great deal of work.

                        if correction.situation.error_count > error_limit then
                           correction.discard()
                        else
                           corrections = find_error_corrections( correction.situation, explain_indent )
                           if corrections.empty? then
                              correction.discard()
                           else
                              corrections.reverse.each do |child_correction|
                                 correction_queue.unshift( child_correction )
                              end
                           end
                        end
                     end
            
                  rescue TokenStream::PositionOutOfRange 
                     correction.discard()
                  rescue AttemptsPending
                     correction.situation.attempts.reverse.each do |attempt|
                        attempt_queue.unshift attempt
                     end
                     
                     pending_queue << correction
                  end
               end
            end
         end
         
         
         #
         # So, we now have a tree of corrected (or partially-corrected) parses that completed (or got to an Attempt).  
         # We must now pick the ones to report to the user.  Presumably, errors are not intentional, so they shouldn't 
         # be too frequent.  We'll therefore pick those solutions that have the fewest errors.  For now, if there's 
         # more than one choice, we'll let the user sort it out.
         
         

         # work
         # if accepted_corrections.empty? then
         #    situation.corrections << failure
         # else
         #    accepted_corrections.sort!{ |a, b| a.situation.corrections.length <=> b.situation.corrections.length }
         # 
         #    fewest_errors         = accepted_corrections[0].situation.correction.length
         #    @corrections          = accepted_corrections.select{ |c| c.situation.corrections.length == fewest_errors }
         # end
         
         
         
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Mid-level Machinery
    #---------------------------------------------------------------------------------------------------------------------
    


      #
      # parse()
      #  - applies the Grammar to the inputs and builds a generic AST
      #  - returns the true if the parse succeeded
      #  - situation is optional -- skip it if you aren't passing one
      
      def parse( situation = nil, explain_indent = nil )
         
         situation = @start_situation if situation.nil?
         
         #
         # Process actions until a solution is found.

         until situation.accepted? or situation.failed?
            
            #
            # Get the state and lookahead.
            
            state, next_token, token_type = situation.look_ahead( nil, explain_indent )
            situation.display( explain_indent, state, next_token ) unless explain_indent.nil?

            #
            # Select the next action.
            
            action = state.actions[token_type]
            
            unless explain_indent.nil? then
               STDOUT.puts "#{explain_indent}| #{state.lookahead_explanations}"
               STDOUT.puts "#{explain_indent}| Action analysis for lookahead #{Token.description(next_token)}"

               if state.explanations.nil? then
                  bug( "no explanations found" )
               else
                  state.explanations[token_type].each do |explanation|
                     explanation.to_s.split("\n").each do |line|
                        STDOUT << "#{explain_indent}|    " << line.to_s << "\n"
                     end
                  end
               end
            end
                        
            #
            # If there is no action, we have an error.  We'll try to recover.  Otherwise, we process the action.

            if !action.nil? then
               perform_action( action, situation, next_token, token_type, explain_indent )
            else
               unless explain_indent.nil? then
                  STDOUT.puts "#{explain_indent}===> ERROR DETECTED: cannot use #{next_token.description}"
                  explain_indent += "   "
               end

               situation.error = Error.new( next_token, state.actions.keys.collect{|t| situation.token_stream.fake_token(t, next_token)} )
            end
         end
         
         return situation.accepted?
      end
      


    protected
      
      #
      # perform_action()
      #  - performs a single action against the current Parser state
      
      def perform_action( action, situation, next_token, token_type, explain_indent )
         case action
            when Plan::Actions::Shift
               situation.shift( next_token, action.to_state, explain_indent )
               situation.position_after( next_token )
               
            when Plan::Actions::Reduce
               raise InvalidReduce.new() unless situation.reduce(action.by_production, @build_ast, explain_indent)
               
            when Plan::Actions::Accept
               situation.accept( explain_indent )
               
            when Plan::Actions::Attempt
               first = true
               child_indent = explain_indent.nil? ? nil : "#{explain_indent}   "
               
               failed = true
               action.actions.each do |attempt_action|
                  unless explain_indent.nil? then
                     if first then
                        first = false
                     else
                        STDOUT.puts "#{explain_indent}" 
                        STDOUT.puts "#{explain_indent}" 
                        STDOUT.puts "#{explain_indent}<=== RETURN"
                     end

                     STDOUT.puts "#{explain_indent}" 
                     STDOUT.puts "#{explain_indent}" 
                     situation.display( explain_indent ) unless explain_indent.nil?
                     STDOUT.puts "#{explain_indent}===> ATTEMPT #{attempt_action.to_s}"
                  end

                  #
                  # Set up a Situation to run our attempt and feed in the selected first action.
                  
                  attempt_situation = situation.cover_for_attempt( attempt_action.is_a?(Plan::Actions::Shift) ? attempt_action.valid_productions : nil )
                  perform_action( attempt_action, attempt_situation, next_token, token_type, child_indent ) 
                  situation.attempts << attempt_situation
               end
               
               raise AttemptsPending.new()
            
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
      
      def find_error_corrections( situation, explain_indent )
         
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

            failed_action = state.actions[token_type]
            symbols       = state.actions.keys
            symbols.each do |leader_type|
               next if leader_type == token_type
               action = state.actions[leader_type]
               
               fake_token = situation.fake_token( leader_type, next_token )

               #
               # Option 1: before next_token, insert valid tokens and see if it changes anything
               
               if correction_worth_trying?( situation, action, failed_action, fake_token ) then
                  situation.position_before( next_token )
                  corrections << situation.correct( fake_token, nil )
               end

               #
               # Option 2: replace next_token with one of our known valid alternatives, provided the replacement 
               # is similar to what the user actually wrote.
               
               if next_token.similar_to?(leader_type) then
                  if correction_worth_trying?( situation, action, failed_action, fake_token )
                     situation.position_after( next_token )
                     corrections << situation.correct( fake_token, next_token )
                  end
               end
            end


            #
            # Option 3: delete next_token and try the one following.
            
            follow_token = situation.la( nil, nil, next_token )
            if state.actions.member?(follow_token.type) then 
               situation.position_before( follow_token )
               corrections << situation.correct( nil, situation.consume() )
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
               worth_trying = true if action.to_state.actions.member?(situation.la(action.to_state, nil, inserted_token).type) 

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
                        worth_trying = true if attempt_action.to_state.actions.member?(situation.la(attempt_action.to_state, nil, inserted_token).type) 

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
      
      class AttemptsPending < ParserFailure
      end
      
      
      
    
    
    
    #---------------------------------------------------------------------------------------------------------------------
    # Low-level Machinery
    #---------------------------------------------------------------------------------------------------------------------
    
    # protected
    # 
    # 
    #   #
    #   # rewind()
    #   #  - rewinds the lexer to where it was when it produced the specified token
    #   
    #   def rewind( before_token )
    #      @token_stream.rewind( before_token )
    #   end
    #   
    #   
    #   #
    #   # set_lexer_plan()
    #   #  - swaps in a new LexerPlan for use with la() and consume()
    #   #  - takes the appropriate action to ensure the next token is from that new plan
    #   #  - doesn't do unecessary work
    #   
    #   def set_lexer_plan( plan )
    #      @token_stream.lexer_plan = plan
    #   end
    # 
    #       
    #   #
    #   # la()
    #   #  - looks ahead one or more tokens
    #   
    #   def la( count = 1, explain_indent = nil )
    #      return @token_stream.la( count, explain_indent )
    #   end
    #   
    #   
    #   #
    #   # consume()
    #   #  - shifts the next token off the lookahead and returns it
    #   
    #   def consume( explain_indent = nil )
    #      return @token_stream.consume( explain_indent )
    #   end
    #   
    #   
      
   end # Parser
   
   
   
   


end  # module Interpreter
end  # module Rethink
