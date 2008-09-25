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
require "#{$RCCLIB}/plan/state.rb"


module RCC
module Plan

 
 #============================================================================================================================
 # class StateTable
 #  - a manager for States

   class StateTable
      
      def self.build( master_plan, start_rule_name, estream = nil )
         start_state = State.start_state( master_plan, start_rule_name )
         start_state.close()
         
         table = new( master_plan, start_state )
         table.build( estream )
         
         return table
      end
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------
    
      attr_reader :states            # The States

      def initialize( master_plan, start_state )
         @master_plan = master_plan
         @states      = [ start_state ]                                # All our states
         @index       = { start_state.signature => start_state }       # {signature => State}
         @work_queue  = [ start_state ]
         @closed      = false
      end
      
      
      def each()
         @states.each do |state|
            yield( state )
         end
      end
      
   
      def []( index )
         return @states[index]
      end
      
      
      #
      # create_state()
      #  - creates a State and adds it to this table
      
      def create_state( start_items, context_state, close = true )
         
         #
         # If a matching state is already is in the index, all we need to do is merge in the lookahead 
         # from the new contexts.  
      
         if state = @index[State.signature(start_items)] then
            state.add_contexts( start_items, context_state )
      
         #
         # Otherwise, we need to create a new State from the shifted_items.
   
         else
            state = State.new( @master_plan, @states.length, start_items, context_state )
            state.close() if close
            
            add_state( state )
         end
         
         
         return state
      end


      #
      # build()
      #  - transitively builds new states from the start state and compiles actions for each
      
      def build( estream = nil )
         compile_syntax( estream )
         compile_lex( estream )
      end

      
      



    #---------------------------------------------------------------------------------------------------------------------
    # Table construction
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
      
      #
      # compile_syntax()
      #  - transitively builds new states from the work queue, one for each follow symbol in the current state
      #  - avoids creating new states that have the same signature as existing states (per LALR(k))
      #  - returns the list of state that were processed
      
      def compile_syntax( estream )
         
         until @work_queue.empty?
            
            #
            # Step 1: Transitively construct states for everything in the work queue.
            
            processed = []
            duration = Time.measure do
               until @work_queue.empty?
                  current_state = @work_queue.shift
                  processed << current_state
               
                  current_state.enumerate_syntactic_transitions do |symbol_name, shifted_items|
                     transition_state = create_state( shifted_items, current_state )
                     current_state.add_transition( symbol_name, transition_state )
                  end
               end
            end
            
            puts "It took #{duration} seconds to enumerate_syntactic_transitions()"
                  
            #
            # Step 2: Close the processed States' Items to new follow contexts.  We'll need this data locked 
            # down for action generation.  Unfortunately, that means we can no longer merge new states with
            # our existing ones, so we clear the signature index.
         
            duration = Time.measure do
               processed.each do |state|
                  state.close_items()
               end
            end
            
            @index.clear()


            #
            # Step 3: Build syntactic actions for the States we processed.  During this process, new states
            # may be added to the table (to properly handle discards).  We'll pick them up on the next go
            # round.
            
            duration = Time.measure do 
               processed.each do |state|
                  state.display
                  state.compile_syntactic_actions( self, estream )
                  # $stdout.with( :state_context => :discards ) do
                  #    state.display
                  #    puts ""
                  #    puts ""
                  # end
               end
            end
            
            puts "It took #{duration} seconds to compile_syntactic_actions()"
         end
      end
      
      
      
      #
      # compile_lex()
      #  - transitively constructs States to handle lexical processing for the existing states
      #  - DO NOT call this untill ALL syntactic states have been built
      #  - you cannot add any more states to this table once you have called this
      
      def compile_lex( estream )
         
         #
         # Step 1: Starting with the existing states, Transitively construct states for all lexical transitions.

         @work_queue = [] + @states
         processed   = []
         
         duration = Time.measure do
            until @work_queue.empty?
               current_state = @work_queue.shift
               processed << current_state
            
               current_state.close()
               current_state.enumerate_lexical_transitions do |vector, shifted_items|
                  transition_state = create_state( shifted_items, current_state )
                  current_state.add_transition( vector, transition_state )
               end
            end
         end
         
         puts "It took #{duration} seconds to enumerate_lexical_transitions()"
         
               
         #
         # Step 2: Close the processed States' Items to new follow contexts.  We'll need this data locked 
         # down for action generation.  As this is the last pass through enumeration, we can clear the
         # signature index.
      
         duration = Time.measure do
            processed.each do |state|
               state.close_items()
            end
         end
         
         @index.clear


         #
         # Step 3: Build lexical actions for the States we processed (the whole table, actually).  Unlike with
         # syntactic action compilation, this is the last hurrah.  We'll be here exactly and only once.
         
         duration = Time.measure do 
            processed.each do |state|
               state.compile_lexical_actions( estream )
            end
         end

         puts "It took #{duration} seconds to compile_lexical_actions()"


         #
         # After this, the state table is closed.

         @closed = true
      end


   
    
    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def display( stream )
         stream << "States\n"
         stream.indent do 
            @states.each do |state|
               state.display( stream )
            end
         end
      end


      #
      # add_state()
      #  - adds a State to this table
      
      def add_state( state )
         assert( !@closed, "you cannot add any more states to this state table, as you have already built the lexical states" )
         
         if @index.member?(state.signature) then
            bug( "can't define duplicate state", state ) 
         else
            state.number = @states.length
            @states << state
            @index[state.signature] = state
            
            @work_queue << state
         end
         
         return state
      end
      
      
   



      
   end # StateTable
   


end  # module Plan
end  # module RCC




