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
require "#{$RCCLIB}/scanner/artifacts/solution.rb"
require "#{$RCCLIB}/scanner/artifacts/nodes/token.rb"
require "#{$RCCLIB}/scanner/artifacts/nodes/asn.rb"
require "#{$RCCLIB}/scanner/artifacts/nodes/csn.rb"
require "#{$RCCLIB}/scanner/artifacts/correction.rb"
require "#{$RCCLIB}/scanner/artifacts/position_stack/position_marker.rb"
require "#{$RCCLIB}/util/tiered_queue.rb"


module RCC
module Scanner
module Interpreter

 
 #============================================================================================================================
 # class Parser
 #  - an interpretive Parser for a Grammar
 #  - useful for testing stuff out

   class Parser
      
      Solution = Artifacts::Solution
      Token    = Artifacts::Nodes::Token
      CSN      = Artifacts::Nodes::CSN
      ASN      = Artifacts::Nodes::ASN
   
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      #
      # initialize()
      #  - initializes this Parser for use
      #  - repair_search_tolerance is used to limit recursion in discover_repair_options()
      
      def initialize( parser_plan, lexer, build_ast = true )
         @parser_plan         = parser_plan
         @lexer               = lexer
         @build_ast           = build_ast
         @work_queue          = []
         @in_recovery         = false
         @recovery_queue      = Util::TieredQueue.new()
      end
      
      
      #
      # connect()
      #  - connect a source (lexer) to the Parser for processing
      
      def connect( lexeer )
         @lexer       = lexer
         @in_recovery = false
         
         @work_queue.clear
         @recovery_queue.clear
      end
      
      
      
      #
      # ::describe_type()
      
      def self.describe_type( type )
         return type.nil? ? "$" : (type.is_a?(Symbol) ? ":#{type}" : "'#{type.gsub("\n", "\\n")}'") 
      end
      
      
            


      #
      # parse()
      #  - parse() drives the parser through attempts and error corrections as far as it can go
      #  - error corrections will not be run indefinitely
      
      def parse( recovery_time_limit = 3, explain_indent = nil )
         recovery_time_limit = 3
         allow_shortcutting  = true
         
         start_position         = PositionMarkers::StartPosition.new(@parser_plan.state_table[0], @lexer)
         hard_correction_limit  = 1000000000
         soft_correction_limit  = 1000000000
         error_queue            = [] 
         complete_solutions     = []
         position               = nil
         
         @in_recovery = false
         error_positions     = {}
         recovery_start_time = nil
         start_time          = Time.now
         until @in_recovery and ((@recovery_queue.empty? and error_queue.empty?) or (Time.now - recovery_start_time > recovery_time_limit))

            if @in_recovery then

               #
               # If the @recovery_queue is empty, pick the best options from the error_queue and generate new
               # recovery positions.  The best options are those with a correction cost lower than the any 
               # complete solutions we've already found, and lower than any of the other errors in the queue.

               if @recovery_queue.empty? then
                  unless explain_indent.nil?
                     STDOUT.puts "#{explain_indent}"
                     STDOUT.puts "#{explain_indent}"
                     STDOUT.puts "#{explain_indent}"
                     STDOUT.puts "#{explain_indent}"
                     STDOUT.puts "#{explain_indent}"
                     STDOUT.puts "#{explain_indent}================================================================================"
                     STDOUT.puts "#{explain_indent}RESETTING FOR NEXT ERROR"
                  end
                  soft_correction_limit = hard_correction_limit
                  
                  discard_threshold = error_queue.inject(hard_correction_limit) {|current, position| min(current, position.corrections_cost) }
                  
                  # error_queue.each do |error_position|
                  #    if error_position.corrections_cost <= discard_threshold then
                  #       signature = error_position.signature()
                  #       if error_positions.member?(signature) then
                  #          error_positions[signature].join_position( error_position )
                  #       else
                  #          error_positions[signature] = error_position
                  #          generate_recovery_positions( error_position, soft_correction_limit )
                  #       end
                  #    end
                  # end
                  
                  error_queue.each do |error_position|
                     if error_position.corrections_cost <= discard_threshold then
                        generate_recovery_positions( error_position, soft_correction_limit )
                     end
                  end
                  
                  error_queue.clear
               end

               #
               # Pick up the next recovery position for processing.  Don't bother if, since it was created,
               # it has become a bad option (by correction_cost).

               position = @recovery_queue.shift
               next if position.nil? or (allow_shortcutting and position.corrections_cost > soft_correction_limit)

               unless explain_indent.nil?
                  STDOUT.puts "#{explain_indent}"
                  STDOUT.puts "#{explain_indent}"
                  STDOUT.puts "#{explain_indent}"
                  STDOUT.puts "#{explain_indent}"
                  STDOUT.puts "#{explain_indent}"
                  STDOUT.puts "#{explain_indent}================================================================================"
                  STDOUT.puts "#{explain_indent}TRYING RECOVERY with cost = #{position.corrections_cost}"
                  STDOUT.puts "#{explain_indent}"
               end

            else
               position = start_position
            end


            #
            # Run the position and handle any errors.

            pass_start_time = Time.now()
            begin
               solution = position = parse_until_error( position, explain_indent )
               complete_solutions << solution
               hard_correction_limit = min( hard_correction_limit, solution.corrections_cost )
               soft_correction_limit = min( hard_correction_limit, soft_correction_limit     )
               
            rescue ParseError => e
               position = e.position
               if position.next_token.tainted? then
                  # we're done -- it's already been corrected and the correction failed
               elsif position.recovered? then
                  STDOUT.puts "#{explain_indent}POSITION IS RECOVERED; QUEUEING NEW ERROR PROCESSING: #{position.description(true)};" unless explain_indent.nil?
                  soft_correction_limit = min( soft_correction_limit, position.corrections_cost )
                  
                  signature = position.signature()
                  if error_positions.member?(signature) then
                     error_positions[signature].join_position( position )
                  else
                     error_positions[signature] = position
                     error_queue << position
                  end
               elsif position.corrections_cost < soft_correction_limit then
                  if position.tainted? then
                     generate_recovery_positions( position, soft_correction_limit, explain_indent )
                  else
                     error_queue << position
                     soft_correction_limit = min( soft_correction_limit, position.corrections_cost ) if @in_recovery
                     unless explain_indent.nil?
                        STDOUT.puts "#{explain_indent}QUEUEING ERROR FOR FURTHER PROCESSING: #{position.description(true)};"
                        STDOUT.puts "#{explain_indent}   CORRECTION LIMIT FOR THIS ERROR IS NOW #{soft_correction_limit}"
                     end
                  end
               else
                  STDOUT.puts "#{explain_indent}TOO MANY ERRORS: DISCARDING POSITION #{position.description(true)}" unless explain_indent.nil?
               end
               
            rescue PositionSeen => e
               position = e.position
               STDOUT.puts "#{explain_indent}DISCARDING LOOPED RECOVERY: #{position.description(true)}" unless explain_indent.nil?
            end
            
            STDOUT.puts "#{explain_indent}PASS TOOK: #{Time.now-pass_start_time}s" unless explain_indent.nil?


            #
            # The first time through only, switch to error recovery mode.

            if !@in_recovery then
               @in_recovery = true
               recovery_start_time = Time.now
            end
         end


         #
         # Generate a list of partial recoveries for reporting.
         
         partial_solutions = []
         discard_threshold = error_queue.inject(hard_correction_limit) {|current, position| min(current, position.corrections_cost) }
         error_queue.each do |error_position|
            if error_position.corrections_cost <= discard_threshold then
               partial_solutions << error_position
            end
         end
         
         complete_solutions = complete_solutions.select{|e| e.corrections_cost <= hard_correction_limit}
         
         #
         # Report errors and corrections.
         
         STDERR.puts "PARSING/ERROR RECOVERY COMPLETED in #{Time.now - start_time}s"
         STDERR.puts "   complete solutions: #{complete_solutions.length}"
         STDERR.puts "   partial solutions:  #{partial_solutions.length}"
         STDERR.puts "   outputting solutions with #{hard_correction_limit} correction cost or better"
         
         return Solution.new( complete_solutions, partial_solutions, @parser_plan.exemplars )
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Mid-level Machinery
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      #
      # parse_until_error()
      #  - applies the Grammar to the inputs and builds a generic AST
      #  - manages FlowControl through Attempts
      #  - raises FlowControl for errors
      #  - returns any solution Position found
      
      def parse_until_error( position, explain_indent = nil )
         solution   = nil
         work_queue = [position]
         
         #
         # We want to avoid deep recursion for attempts.  Life would be a lot easier if we didn't care, but we do.
         # So, the underlying structures will throw FlowControl exceptions we use to manage our place.  We keep track
         # of which AttemptPosition is in which set by use of an attempt_depth marking, which we maintain.
         #
         # Error recovery with attempts is tricky, because if something goes wrong, we'll have several positions
         # from which to start error recovery (the terminal position for each attempt in the set).  That said, we 
         # don't want to keep those positions as suspect forever -- once one of the attempts succeeds, we're probably 
         # done with the alternate recovery positions produced by that attempt set.  
         #
         # We manage error recovery options by accumulating recovery positions in our position stack.  After an attempt 
         # fails, we add its last-processed position and any of its alternate recovery positions to the next AttemptPosition
         # as alternate recovery positions.  If we run out of attempts before finding a solution, we raise a ParseError
         # for the last position tried.  The error recovery code will then ensure that all our alternates are considered, 
         # when the time comes.
         #
         # This method works great for AttemptPositions that launch with a Shift.  The AttemptPosition will be on the
         # stack of active positions until it is Reduced off, indicating that we have successfully left the attempt
         # and are on to bigger things.  At this point, all the alternate recovery positions are irrelevant, and naturally 
         # fall from our attention when the AttemptPosition leaves the stack.  The problem is that if the AttemptPosition 
         # launches with a Reduce, it *immediately* leaves the stack.  Oops.  So, in this one case, we'll transfer any 
         # alternate recovery positions to the resulting position.  That position will stay on the stack until it is reduced
         # off, and that should be long enough to get us past any need for the alternate recovery positions from the set.
         #
         # Whew.  My brain hurts.
         
         until solution.exists? or work_queue.empty?
            position      = work_queue.shift
            attempt_depth = 0
            
            #
            # If the current position is an AttemptPosition, we have some setup work to do.  See the notes above
            # for details.  Note that we shoud never get a FlowControl exception from our launch action, as the
            # thing that created the AttemptPosition already verified the lookahead.
            
            if position.is_a?(PositionMarkers::AttemptPosition) then
               attempt_depth = position.attempt_depth
               next_position = perform_action( position, position.launch_action, position.next_token, explain_indent )
               
               #
               # Shift actions will make a new position with the old position as context.  Reduce actions will
               # make a new position without the old position as context.  In the latter case, we need to transfer
               # our recovery suspicions to the new position, so they don't immediately fall off the stack.
               
               if next_position.context.object_id != position.object_id then
                  next_position.alternate_recovery_positions.concat( position.alternate_recovery_positions )
               end
               
               position = next_position
            end
            

            #
            # So, we're all set and ready to go.  Parse until some FlowControl indicates we have work to do.
            
            begin
               solution = parse_until_branch_point( position, explain_indent )
               
               
            #
            # AttemptsPending is thrown to send us a new batch of AttemptPositions.  We reverse them onto the head of
            # our work_queue in order to process in the "natural" order.
            
            rescue AttemptsPending => e
               e.attempts.reverse.each do |child_attempt|
                  child_attempt.attempt_depth = attempt_depth + 1
                  work_queue.unshift child_attempt
               end
               
            #
            # ParseFailed is thrown if the parse encountered an error (ParseError), or if the parser attempted
            # to Reduce past an AttemptPosition with something other than the exected Productions (AttemptFailed).
            # This latter one generally occurs when the code parsed, but was reduced by a Production from one of our 
            # peer Attempts.
            
            rescue ParseFailed => e
               attempt_context = e.position.attempt_context
               
               #
               # If there is no attempt_context, all attempts have been successful, and our work_queue is irrelevant.
               # Re-raise the error.  Note that AttemptFailed will never trigger this condition.
               
               raise if attempt_context.nil?
               
               #
               # Discard things from our work_queue that were made irrelevant by the actual parse -- ie. any peers to 
               # attempts that succeeded.  We need the next thing on the stack (if anything) to be the AttemptPosition 
               # to try next (a peer in this set, or something in a context set).  
               
               work_queue.shift until (work_queue.empty? or work_queue[0].attempt_depth <= attempt_context.attempt_depth)
               
               #
               # If the work_queue is empty, we failed.  Raise an error.
               
               raise ParseError.new( e.position ) if work_queue.empty?
               
               #
               # Otherwise, the error becomes an alternate recovery position for the next work_queue position.
               
               work_queue[0].alternate_recovery_positions.concat( e.position.alternate_recovery_positions )
               work_queue[0].alternate_recovery_positions << e.position
               
            end
         end

         return solution
      end
      
      

      #
      # parse_until_branch_point()
      #  - applies the Grammar to the inputs and builds a generic AST
      #  - raises FlowControl on branch points
      #  - returns any solution Position found
      
      def parse_until_branch_point( position, explain_indent = nil )
         solution = nil
         
         #
         # Process actions until a solution is found or an exception is raised (AttemptsPending, for instance).
         
         while solution.nil?
            
            #
            # Get the lookahead.
            
            state      = position.state
            next_token = position.next_token( explain_indent )
            
            position.display( STDOUT, explain_indent ) unless explain_indent.nil?
            
            #
            # Select the next action.
            
            action = state.actions[next_token.type]
            unless explain_indent.nil? then
               STDOUT.puts "#{explain_indent}| #{state.lookahead_explanations}"
               STDOUT.puts "#{explain_indent}| Action analysis for lookahead #{next_token.description}"

               if state.explanations.nil? then
                  bug( "no explanations found" )
               else
                  state.explanations[next_token.type].each do |explanation|
                     explanation.to_s.split("\n").each do |line|
                        STDOUT << "#{explain_indent}|    " << line.to_s << "\n"
                     end
                  end
               end
            end
                        
            #
            # If there is no action, we have an error.  We'll try to recover.  Otherwise, we process the action.
            # perform_action() raises an AttemptsPending exception if it encounters a branch point -- we pass it
            # through to our caller.

            if action.exists? then
               if action.is_a?(Plan::Actions::Accept) then
                  solution = position
               else
                  position = perform_action( position, action, next_token, explain_indent )
               end
            else
               unless explain_indent.nil? then
                  STDOUT.puts "#{explain_indent}===> ERROR DETECTED: cannot use #{next_token.description}"
                  explain_indent += "   "
               end

               raise ParseError.new( position )
            end
            
         end
         
         return solution
      end
      

      #
      # perform_action()
      #  - performs a single action against a Position 
      #  - returns the next Position to process, or nil when the last position was accepted
      #  - raises AttemptsPendings if the parse hit a branch point
      #  - raises PositionSeen if the action has a recovery context and would duplicate a position already seen
      
      def perform_action( position, action, next_token, explain_indent )
         next_position = nil
         
         case action
            when Plan::Actions::Shift
               STDOUT.puts "#{explain_indent}===> SHIFT #{next_token.description} AND GOTO #{action.to_state.number}" unless explain_indent.nil?
               next_position = position.push( next_token, action.to_state )
               
            when Plan::Actions::Reduce
               production = action.by_production
               STDOUT.puts "#{explain_indent}===> REDUCE #{production.to_s}" unless explain_indent.nil?
               
               #
               # Pop the right number of nodes.  Position.pop() may through an exception if it detects an error.  
               # We pass it through to our caller. 
               
               nodes = []
               top_position = position
               production.symbols.length.times do |i|
                  nodes.unshift position.node
                  position  = position.pop( production, top_position )
               end
               
               node = @build_ast ? ASN.map(production, nodes) : CSN.new(production.name, nodes)
               
               #
               # Untaint the node if the error recovery is complete.
               
               if node.tainted? then
                  if next_token.rewind_position > node.original_error_position then
                     STDOUT.puts "#{explain_indent}UNTAINTING" unless explain_indent.nil?
                     node.untaint()
                  end
               end
               
               #
               # Create/transfer recoverability marks, if appropriate.
               
               if production.name == "statement".intern then
                  node.recoverable = true
               elsif nodes[-1].recoverable? then
                  node.recoverable = true
               end
                                 
               #
               # Get the goto state from the now-top-of-stack State: it will be the next state.
               
               goto_state = position.state.transitions[production.name]
               STDOUT.puts "#{explain_indent}===> PUSH AND GOTO #{goto_state.number}" unless explain_indent.nil?

               next_position = position.push( node, goto_state, top_position )

            when Plan::Actions::Attempt
               
               #
               # position.fork() for each of our options and feed in the selected first action.  We can rely on this
               # never being another Attempt action.  Once all are set up, raise an AttemptsPending exception to 
               # pass the list back to somebody who can do something about it.  Doing things this way helps us prevent
               # stack overflow from deep recursion.
               
               attempts = action.actions.collect do |attempt_action|
                  valid_productions = attempt_action.is_a?(Plan::Actions::Shift) ? attempt_action.valid_productions : nil
                  position.fork( attempt_action, valid_productions )
               end
               
               raise AttemptsPending.new( attempts )
            
            else
               nyi "support for #{action.class.name}"
         end

         return next_position
      end


      
      #
      # resolve_reference_predicate()
      #  - searches the Position stack for the first non-reference recovery Predicate matching the leader_type

      def resolve_reference_predicate( position, leader_type )
         # action = position.state.actions[leader_type]
         # while action.is_a?(Plan::Actions::Reduce)
         #    position  = perform_action( position, action, nil, nil )
         #    predicate = position.state.recovery_predicates[leader_type]
         #    if predicate.is_a?(Plan::Predicates::CheckContext) then
         #       action = position.state.actions[leader_type]
         #    else
         #       return predicate
         #    end
         # end
         # 
         # return nil
         # 
         # 
         
         #
         # Create a simulated State stack
         
         states = []
         position.each_position do |position|
            states.unshift position.state
         end
         
         #
         # Process referals until we find a predicate that isn't one.
         
         action = states[-1].actions[leader_type]
         while action.is_a?(Plan::Actions::Reduce)
            
            #
            # Simulate the current REDUCE
            
            action.by_production.symbols.length.times do
               states.pop
            end
            
            states.push states[-1].transitions[action.by_production.name]
            
            #
            # Get the next recovery predicate and set up for the next attempt.
            
            predicate = states[-1].recovery_predicates[leader_type]
            if predicate.is_a?(Plan::Predicates::CheckContext) then
               action = states[-1].actions[leader_type]
            else
               return predicate
            end
         end

         return nil
      end
      






    #---------------------------------------------------------------------------------------------------------------------
    # Error Recovery
    #---------------------------------------------------------------------------------------------------------------------
    #
    # Error recovery in rcc involves trying to alter then token stream in order to produce a valid parse.  This is 
    # predicated on the idea that the user isn't trying to produce bad code -- that the errors are, in fact, accidents.
    # 
    # We can alter the token stream in three ways: by inserting a token; by replacing a token; or by deleting a token.
    # Generally speaking, we trust deletion the least, as users are lazy: they don't do generally do work the didn't think 
    # they needed.  As a result, we try deletions last.  Replacing a token is something we trust a little more, but only 
    # if the replacement token can be considered lexically similar to the one that was already there.  For instance, we 
    # might replace "++" with "+" to produce a valid parse, or the identifer "fi" with the keyword "if"; but we should not 
    # arbitrarily replace keyword "class" with operator "*", as it is unlikely the user meant one and typed the other.
    # We rely on machinery in Token for this comparison.  Finally, insertion of a token is our favourite choice.  It seems
    # far more likely that a user forgot to type something, than typed something extra.
    #
    # The parser works with a "stack" of position markers (it is maintained as a linked list, but behaves like a stack).
    # Shift actions create new positions at the head of the stack, and Reduce actions remove one or more positions from
    # the stack and replace them with a new position.  rcc limits its error recovery attempts to positions currently
    # on the position stack.  This generally means that token stream modifications start at the error position, then 
    # jump larger and larger distances back through the source text, looking for ways to fix the token stream.  The idea 
    # is that there is no point error correcting stuff that has already matched Productions, unless as the result of a 
    # upstream token change.  Let's consider a Ruby example: imagine that we have a dozen lines of valid code processed 
    # and reduced to statements, then encounter an unexpected "end" marker.  It is unlikely all of that valid code needs 
    # reinterpretation.  It parsed right once; changing it is only likely to break it.  The user may have put the extra 
    # "end" in by accident; or they may have forgotten a "begin" before one of those valid statements; or they may have 
    # forgotten a "class <name>" or something similar at the very top of the file.  By error correcting only at positions 
    # still on the stack, we conveniently leap to those suspicious points. 
    #
    # Fortunately, at any given position there are a limited number of token stream changes we can make without 
    # immediately creating a new error.  These are the supported lookahead types from the position's State's action set.  
    # We error correct by inserting/replacing to one of these, or by deleting the next token and seeing what happens.
    # And, for obvious reasons, we NEVER do anything if the lookahead token is one the error correction system itself
    # created.
    #
    # Unfortunately, error recovery interacts very badly with backtracking.  Backtracking is used by the parser to
    # process ambiguous grammars -- if the same token stream could possibly have two (or more) different meanings, the 
    # parser tries them both (all).  Each time it hits a dead end, it backtracks to the branch point and tries the next
    # option.  This complicates error recovery because, if an error happens before we've gotten past the ambiguity,
    # we have to consider that the error may have been in any *one* of the branches we tried -- not just the last.  
    # Further, really ambiguous grammars may nest ambiguities within ambiguities, creating a nightmare of complexity for
    # the error recovery system to sort out.  parse_until_error() is used to drive a parse across multiple branches, and 
    # it is responsible for setting up any error recovery operation that becomes necessary.  Each time a branch dead-ends,
    # parse_until_error() adds its last position as an alternate error recovery position on the next branch.  This effect
    # is cumulative, so each branch ends up with all its prececessors last positions as alternate recovery points.  If
    # none of the branches succeed, the error recovery system is passed the whole mess, and must generate corrections on
    # all direct and alternate recovery positions it finds there.
    #
    # parse_until_error() stores the alternate recovery points on or near the stack position that launched the branch.  As 
    # such, recovery positions from the ambiguity will be retired automatically when the position is reduced from the 
    # stack.  From then on, as with normal error recovery, the ambiguity will only be reconsidered as the result of an 
    # upstream token change.
    #
    #
    # Optimizations
    #---------------------------------------------------------------------------------------------------------------------
    #
    # Unfortunately, there are lots of potential error corrections that will go nowhere at all.  For instance, inserting a
    # "-" in front of an expression like "10 + 10" in a math-like language isn't going to materially change the parse (you 
    # trade one expression for another).  Any downstream errors will still occur, regardless.  We need to avoid such 
    # corrections because -- especially with ambiguous grammars -- they could trigger a great deal of pointless reparsing.
    # Similarly, given a token stream like "10 11" in the same math-like language, there is little point inserting a "-" 
    # between "10" and "11" after we have tried "+" -- once one works, the other will add no new information, and the 
    # suggestion of adding a "+" should be sufficient to get the user fixing the problem.
    #
    # At some future date, my plan is to try to pre-calculate which insertions are worth trying for each State.  As of
    # this moment, though, I haven't figured out how to do that (actually, I hadn't thought of trying until I started
    # writing up this documentation today).  Hopefully, it'll turn out to be something simple and obvious.  For now, 
    # though, we'll just try to identify dead-ends at run-time, when the token stream is finite and understood.  To be 
    # honest, I'm a bit gunshy of trying predictive stuff with LR grammars again -- I dumped two days into that dead-end 
    # earlier in the development of rcc (when figuring out how to do backtracking).
    #
    # The simplest solution at run-time is to construct a signature for each position: something that will produce the same
    # signature if we find ourselves in that position again.  Presently, we use a concatenation of node name and state 
    # number from all positions on the stack, combined with the lookahead's stream position.  I'm not yet sure it is
    # right/sufficient, but it will do for now.
    #
    # perform_action() maintains the signature registry.  Each time it produces a new position, we add it to the registry.
    # This is the simple part.  The actual work is done in the recovery phase, when we must check if the position has
    # been seen before.  Unfortunately, there's a problem: there are some positions we want to be able to repeat.
    #
    # Consider the simplest case: just before accepting the parse, the stack will generally have one position (the 
    # reduced start-rule), and the EOF will be on lookahead.  Regardless of how we get there, this about-to-be-accepted
    # position will ALWAYS have the same signature.  Which means, if we aren't smart about it, we will only ever accept
    # one error recovery -- the first one we come across.  Even if there are better options.  That's not much of an 
    # error recovery system.
    #
    # So here's what we're going to do, for now.  I'm not sure it is right/sufficient, but it's a start.  Instead of 
    # checking EVERY position against the position registry, we are going to check only on Reduce, and only if there is
    # AT LEAST one corrected position being popped from the stack during the Reduce.  My hope is that, while this may 
    # allow unnecessary identical parses to continue, this policy should cut down on lots of noise without eliminating 
    # any necessary parses.  It definitely allows the Accept action to proceed after each successful error correction.
    #
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
    
      #
      # generate_recovery_positions()
      #  - given an error position, generates a list of potential recovery positions
      
      def generate_recovery_positions( position, correction_limit, explain_indent = nil )
         recovery_positions = []
         STDOUT.puts "#{explain_indent}CALCULATING RECOVERIES for: #{position.description(true)}" unless explain_indent.nil?

         #
         # First, generate insertions and deletions at each stack point still available for error correction
         # (ie. not already corrected).
         #
         # BUG: The registry used to be produced from each start position, regardless of the actual recovery context.
         # With this version, we are now switching it back to the recovery context.  If things break, that may be
         # why.
         
         error_type = position.next_token.type
         registry   = position.allocate_recovery_registry
         position.each_recovery_position do |recovery_position|
            next if recovery_position.start_position? 
            recovery_context = recovery_position.tainted? ? recovery_position.recovery_context : position
            
            STDOUT.puts "#{explain_indent}   TRYING REPAIR at: #{recovery_position.description(true)}" unless explain_indent.nil?
            lookahead_type = recovery_position.next_token.type

            #
            # Apply the recovery Predicates from the State, and create corrected positions for any that
            # pass.

            recovery_position.state.recovery_predicates.each do |leader_type, predicate|
               STDOUT.puts "#{explain_indent}      APPLYING PREDICATE FOR CORRECTION #{Parser.describe_type(leader_type)}" unless explain_indent.nil?
               next if leader_type.nil? or leader_type == lookahead_type

               #
               # Process the predicate and set flags for our recovery options.

               predicate = resolve_reference_predicate( position, leader_type ) if predicate.is_a?(Plan::Predicates::CheckContext)
               next if predicate.nil?

               replace = predicate.replace?
               insert  = predicate.insert?

               case predicate
                  when Plan::Predicates::CheckErrorType
                     unless error_type == predicate.error_type 
                        replace = false
                        insert  = false
                     end
               end

               #
               # Token replacement is one option.  But we never attempt to replace the EOS marker.

               if replace and !lookahead_type.nil? then
                  if recovery_position.next_token.similar_to?(leader_type) then
                     STDOUT.puts "#{explain_indent}         [#{leader_type}] SIMILAR to [#{lookahead_type}]; WILL TRY REPLACE" unless explain_indent.nil?
                     begin
                        recovery_positions.unshift recovery_position.correct_by_replacement( leader_type, recovery_context ) 
                     rescue PositionSeen => e
                        STDOUT.puts "#{explain_indent}            ===> dead end" unless explain_indent.nil?
                     end
                  else
                     STDOUT.puts "#{explain_indent}         [#{leader_type}] NOT SIMILAR to [#{lookahead_type}]; WON'T TRY REPLACE" unless explain_indent.nil?
                  end
               end

               #
               # Token insertion is another option.

               if insert then
                  STDOUT.puts "#{explain_indent}         WILL TRY INSERTING [#{leader_type}]" unless explain_indent.nil?
                  begin
                     recovery_positions.unshift recovery_position.correct_by_insertion( leader_type, recovery_context )
                  rescue PositionSeen => e
                     STDOUT.puts "#{explain_indent}            ===> dead end" unless explain_indent.nil?
                  end
               end
            end


            #
            # We can also try deleting tokens until we find something we can use.  
            # BUG: THIS IS BORKED BY PositionSeen

            deleted_tokens = []

            begin
               recovered_position = recovery_position.correct_by_deletion( recovery_context )
               until recovered_position.nil?
                  deleted_tokens << recovered_position.next_token().last_correction.deleted_token
                  break if recovered_position.next_token.type.nil? or recovered_position.state.actions.member?(recovered_position.next_token.type)

                  recovered_position = recovered_position.correct_by_deletion( recovery_context )
               end
            rescue PositionSeen => e
               deleted_tokens
            end

            STDOUT.puts "#{explain_indent}      WILL TRY DELETING [#{deleted_tokens.collect{|t| t.description}.join(", ")}]" unless explain_indent.nil?

            recovery_positions.unshift recovered_position unless recovered_position.nil?
         end


         #
         # Move the corrected positions on @recovery_queue.  We try to ensure that the corrections closts to the
         # original error get attempted first, but this will not override lower-cost solutions further away.

         STDOUT.puts "#{explain_indent}   QUEUING GENERATED RECOVERIES" unless explain_indent.nil?
         recovery_positions.each do |recovery_position|
            corrections_cost = recovery_position.corrections_cost
            if corrections_cost <= correction_limit then
               STDOUT.puts "#{explain_indent}      QUEUING POSITION #{recovery_position.description(true)} @ #{recovery_position.corrections_cost}" unless explain_indent.nil?
               @recovery_queue.insert recovery_position, corrections_cost
            else
               STDOUT.puts "#{explain_indent}      TOO MANY ERRORS: DISCARDING POSITION #{position.description(true)}" unless explain_indent.nil?
            end
         end  
      end










    #---------------------------------------------------------------------------------------------------------------------
    # Flow Control Exceptions
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
    
      class FlowControl < ::Exception
      end
      
      
      #
      # AttemptsPending
      #  - raised when parse_until_branch_point() reaches a branch point
      
      class AttemptsPending < FlowControl
         attr_reader :attempts
         
         def initialize( attempts )
            @attempts = attempts
         end
      end
      
      
      #
      # ParseFailed
      #  - base class for things that can indicate parsing could not proceed
      
      class ParseFailed < FlowControl
         attr_reader :position
         
         def initialize( position )
            @position = position
         end
      end
      
      
      #
      # AttemptFailed
      #  - raised when an Attempt branch has failed due to an invalid reduction
      
      class AttemptFailed < ParseFailed
         attr_reader :actual_production
         attr_reader :expected_productions
         
         def initialize( actual_production, expected_productions, top_position )
            super( top_position )
            
            @actual_production   = actual_production
            @expected_production = expected_productions
         end
      end
      
      
      #
      # ParseError
      #  - raised when an error is encountered
      
      class ParseError < ParseFailed
      end
      
      
      #
      # UnrecoverableParseError
      #  - raised when an error is encountered and can't be corrected
      
      class UnrecoverableParseError < ::Exception
         attr_reader :parse_error
         
         def initialize( parse_error )
            @parse_error = parse_error
         end
      end


      #
      # PositionSeen
      #  - raised when a Position has already been seen during error recovery
      
      class PositionSeen < FlowControl
         attr_reader :position
         
         def initialize( position )
            @position = position
         end
      end
      
      
      
    
      
   end # Parser
   
   
   
   


end  # module Interpreter
end  # module Scanner
end  # module RCC