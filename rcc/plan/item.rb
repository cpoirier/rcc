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

module RCC
module Plan

 
 #============================================================================================================================
 # class Item
 #  - an Item in a State

   class Item
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :production           # The Production for this Item 
      attr_reader   :at                   # The mark in the Form at which this Item is working
      attr_reader   :follow_contexts      # The Items from which we inherit our follow terminals
      attr_accessor :start_item           # Indicates if the Item is a start item in its State
      attr_reader   :signature            # A signature for this Item's primary data (production and mark) 
                                  
      def initialize( production, at = 0, follow_contexts = [], production_sets = nil )
         @production       = production
         @at               = at
         @follow_contexts  = []
         @followers        = nil
         @follow_sequences = nil
         @start_item       = false
         @signature        = self.to_s
         @production_sets  = production_sets
         
         follow_contexts.each do |item|
            add_follow_context( item )
         end

         #
         # BUG: verify this:
         
         assert( @signature.index("\n").nil?, "you aren't handling newlines in signatures" )
      end       
      
      def hash()
         return @production.hash
      end
      
      
      def eql?( rhs )
         return false unless rhs.is_a?(Item)
         return self.signature == rhs.signature
      end
      
      
      def rule_name
         return @production.rule_name
      end
      
      

      #
      # complete?()
      #  - returns true if the underlying form is complete in this Item (ie. ready for reduce)
      
      def complete?()
         return @at >= @production.symbols.length 
      end

      
      #
      # shift()
      #  - returns an Item like this one, but shifted one position to the right
      
      def shift()
         if complete? then
            return nil
         else
            return Item.new( @production, @at + 1, [] + @follow_contexts, @production_sets )
         end
      end
      
      
      #
      # leader()
      #  - returns the next Symbol from the mark
      
      def leader()
         return @production.symbols[@at]
      end
      
      
      #
      # determinants()
      #  - returns a list of tokens that will be used to decide what do to for this item
      #     - for a complete item, this is the next token on lookahead, calculated by asking our contexts 
      #       for the list of terminals that can follow their leader (we are the leader)
      #     - for an incomplete item, returns the next token
      
      def determinants( k = 1, production_sets = nil )
         assert( k == 1, "only k = 1 supported, presently" )
         
         production_sets = @production_sets if production_sets.nil?
         assert( !production_sets.nil?, "you must supply a hash of ProductionSets to determinant() when it is calculated" )
         
         return sequences_after_mark(k, production_sets).start_terminals(production_sets)
      end
      
      
      
      #
      # followers()
      #  - returns the list of terminals which may legitimately follow the leader()
      #  - this is a dynamic calculation, and should not be relied upon until the entire state table is built!
      #  - for now, this is k = 1
      
      def followers( production_sets = nil, loop_detection = nil )
         production_sets = @production_sets if production_sets.nil?
         assert( !production_sets.nil?, "you must supply a hash of ProductionSets to followers() when it is calculated" )
         
         return sequences_after_leader( 1, production_sets ).start_terminals(production_sets)
      end


      #
      # production_la()
      #  - returns the terminals that can follow our Production, were it to be complete
      
      def production_la( k = 1, production_sets = nil )
         assert( k == 1, "only k = 1 supported, presently" )
         return @production_la unless @production_la.nil?

         production_sets = @production_sets if production_sets.nil?
         assert( !production_sets.nil?, "you must supply a hash of ProductionSets to followers() when it is calculated" )
         
         sequence_sets = @follow_contexts.collect do |context|
            if context.nil? then
               SequenceSet.end_of_input_set
            else
               set = context.sequences_after_leader( k, production_sets )
            end
         end
         
         @production_la_sequences = SequenceSet.merge( sequence_sets )
         @production_la = @production_la_sequences.start_terminals( production_sets )
         
         return @production_la
      end
         
         
         

      
      
      #
      # sequences_after_mark()
      #  - transitively constructs all potential symbol sequences that can be seen looking "down" the rule 
      #    from the mark and flowing into the lookahead, as necessary
      #  - may return more symbols than you requested, but won't return fewer unless there really are none to be had
      
      def sequences_after_mark( length = 1, production_sets = nil, loop_detection = [] )
         return @sequences_after_mark unless @sequences_after_mark.nil? or @sequences_after_mark.length < length
         return SequenceSet.empty_set() if loop_detection.member?(self.object_id)
         
         production_sets = @production_sets if production_sets.nil?
         assert( !production_sets.nil?, "you must supply a hash of ProductionSets to sequences_after_mark() when it is calculated" )

         #
         # Satisfy as much of the request as possible locally.  If the request is fully satisfied without going
         # to our follow contexts, all the better.
         
         local_symbols = rest()
         if local_symbols.length >= length then
            @sequences_after_mark = SequenceSet.single( local_symbols )
            
         #
         # Otherwise, we have to go to our follow contexts for additional symbols.  We don't want the
         # leader symbol from our contexts, as we ARE that leader symbol.
         
         else
            loop_detection = [self.object_id] + loop_detection
            sequence_sets = @follow_contexts.collect do |context|
               if context.nil? then
                  SequenceSet.end_of_input_set
               else
                  set = context.sequences_after_leader( length - local_symbols.length, production_sets, loop_detection )
               end
            end
            
            @sequences_after_mark = SequenceSet.merge( sequence_sets ).prefix( local_symbols )
         end
         
         return @sequences_after_mark
      end
      
      
      #
      # sequences_after_leader()
      #  - similar to sequences_after_mark, but skips the leader 
      #  - may return more symbols than you requested, but won't return fewer unless there really are none to be had
      
      def sequences_after_leader( length = 1, production_sets = nil, loop_detection = [] )
         sequences = sequences_after_mark( length + 1, production_sets, loop_detection )
         return sequences.slice( 1..-1 )
      end
      
      
      
      #
      # prefix()
      #  - returns the Symbols from before the mark
      
      def prefix()
         return @production.symbols.slice( 0, @at )
      end
      
      
      
      #
      # rest()
      #  - returns a Phrase of those Symbols from this Item that follows the mark
      
      def rest( offset = 0 )
         slice = @production.symbols.slice( (@at + offset)..-1 )
         return slice.nil? ? [] : slice
      end
      
      
      
      #
      # add_follow_context()
      #  - adds a follow context, which can be used when calculating lookahead 
      
      def add_follow_context( item )
         type_check( item, Item, true )
         
         unless @follow_contexts.member?(item)
            @follow_contexts << item
         end
      end
      
      
      #
      # add_follow_contexts_from( )
      #  - adds the follow contexts from another Item
      
      def add_follow_contexts_from( item )
         item.follow_contexts.each do |context_item|
            add_follow_context( context_item )
         end
      end
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         base = rule_name() + " => " + prefix().join(" ") + " . " + rest().join(" ")
      end
      
      def display( stream, indent = "" )
         stream << indent << self.to_s << "     >>>  " << self.followers.join("|") << "\n"
      end

     
   end # Item
   


end  # module Plan
end  # module Rethink

