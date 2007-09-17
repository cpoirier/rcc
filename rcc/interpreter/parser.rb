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
require "#{$RCCLIB}/interpreter/error.rb"
require "#{$RCCLIB}/interpreter/csn.rb"
require "#{$RCCLIB}/interpreter/asn.rb"
require "#{$RCCLIB}/interpreter/markers/general_position.rb"


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
      
      def initialize( parser_plan, lexer, build_ast = true )
         @parser_plan         = parser_plan
         @lexer               = lexer
         @build_ast           = build_ast
         @work_queue          = []
         
         @in_recovery         = false
         @pre_error_positions = []
         @position_registry   = {}   
      end
      
      
      #
      # ::describe_type()
      
      def self.describe_type( type )
         return type.nil? ? "$" : (type.is_a?(Symbol) ? ":#{type}" : "'#{type.gsub("\n", "\\n")}'") 
      end
      
      
            


      #
      # go()
      #  - go() drives the parser through attempts and error corrections as far as it can go
      #  - error corrections will not be run indefinitely
      
      def go( recovery_time_limit = 3, explain_indent = nil )
         solution       = nil
         recovery_queue = []
         

         #
         # First, run the initial parse.  With a bit of luck, there'll be no errors, and we can just return 
         # the solution: no fuss, no muss.
         
         3.times { STDOUT.puts "" }
         STDOUT.puts "#{explain_indent}===> PARSING BEGINNING" 

         begin
            solution = parse_until_error( Markers::StartPosition.new(@parser_plan.state_table[0], @lexer), explain_indent )
            return solution.node
         rescue ParseError => e
            generate_recovery_positions( e.position, explain_indent ).reverse_each do |recovery_position|
               recovery_queue.unshift recovery_position
            end
         end

         STDOUT.puts "#{explain_indent}===> PARSING FAILED" 
         
         
         #
         # If we are still here, it's time to start error recovery.  For each recovery_queue position, we'll
         # look for and apply corrections in depth-first order.  We'll give it recovery_time_limit seconds to 
         # find the best corrections, and the underlying system will direct this toward real soutions by use 
         # of position signatures to shortcut out of pointless corrections.
         
         5.times { STDOUT.puts "" }
         STDOUT.puts "#{explain_indent}===> ERROR RECOVERY BEGINNING" 

         @in_recovery = true
         @pre_error_posotions.each do |visited_position|
            @position_registry[visited_position.signature] = true
         end
         
         error_limit = 1000000000
         start_time  = Time.now()
         solutions   = []
         
         until recovery_queue.empty? or (Time.now - start_time > recovery_time_limit)
            restart_position = recovery_queue.shift
            unless restart_position.correction_count > error_limit
               begin
                  solution = parse_until_error( restart_position, explain_indent )
                  solutions << solution
               rescue ParseError => e
                  generate_recovery_positions( e.position, explain_indent ).reverse_each do |recovery_position|
                     recovery_queue.unshift recovery_position
                  end
               rescue PositionSeen => e
                  # no op -- it's a dead-end
               end   
            end
         end
         
         STDOUT.puts "#{explain_indent}===> ERROR RECOVERY COMPLETE" 

         
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
            
            if position.is_a?(Markers::AttemptPosition) then
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
         
         while true
            
            #
            # Get the lookahead.
            
            state      = position.state
            next_token = position.next_token( explain_indent )
            
            position.display( explain_indent, next_token ) unless explain_indent.nil?
            
            #
            # Select the next action.
            
            action = state.actions[next_token.type]
            unless explain_indent.nil? then
               STDOUT.puts "#{explain_indent}| #{state.lookahead_explanations}"
               STDOUT.puts "#{explain_indent}| Action analysis for lookahead #{next_token.description}"

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
               corrected    = false
               production.symbols.length.times do |i|
                  nodes.unshift position.node
                  corrected = true if position.corrected?
                  position  = position.pop( production, top_position )
               end
               
               #
               # Get the goto state from the now-top-of-stack State: it will be the next state.
               
               goto_state = position.state.transitions[production.name]
               STDOUT.puts "#{explain_indent}===> PUSH AND GOTO #{goto_state.number}" unless explain_indent.nil?

               next_position = position.push( @build_ast ? ASN.new(production, nodes[0].first_token, nodes) : CSN.new(production.name, nodes), goto_state, top_position )

               #
               # Raise PositionSeen if appropriate.  
               
               raise PositionSeen.new( top_position ) if corrected and @position_registry.member?(next_position.signature)
               
               
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

         #
         # Maintain the signature registry.  If we are in the recovery phase, this means storing the next_position
         # signature.  If in the initial (pre-error) parse phase, we'll just save the position object for later
         # signature production.  We do this as a cost savings measure.  go() will take care over moving the 
         # @pre_error_positions into the @signature_registry, when the time comes.
         
         if @in_recovery then
            @position_registry[next_position.signature] = true
         else
            @pre_error_positions << next_position
         end

         return next_position
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
      
      def generate_recovery_positions( position, explain_indent )
         corrections = []
         
         #
         # Work back from the supplied position to the root.  We will try inserting, replacing, or deleting a 
         # token at the lookahead for each position.  We generate all potential corrections and let the error
         # recovery code sort them out.
         
         recovery_context = position
         until position.nil?
            
            #
            # Never muck with a faked token -- infinite loops lie there . . . .
            
            unless position.next_token.faked?
               lookahead_type = position.next_token.type
               
               position.state.actions.keys.each do |leader_type|
                  next if leader_type == lookahead_type
                  
                  corrections << position.correct_by_insertion( leader_type, recovery_context )
                  corrections << position.correct_by_replacement( leader_type, recovery_context )
                  corrections << position.correct_by_deletion( recovery_context )
               end
            end
            
            position = position.context
         end
         
         return corrections
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
            
            @actual_production    = actual_production
            @exptected_production = expected_productions
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
