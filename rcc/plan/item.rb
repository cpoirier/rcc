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
require "#{$RCCLIB}/util/recursion_loop_detector.rb"

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
      attr_reader   :follow_sources       # The Items from which we ihherit additional follow contexts
      attr_accessor :start_item           # Indicates if the Item is a start item in its State
      attr_reader   :signature            # A signature for this Item's primary data (production and mark) 
      attr_reader   :shifted_from_item
      
                                  
      def initialize( production, at = 0, follow_contexts = [], production_sets = nil, shifted_from_item = nil )
         @production       = production
         @at               = at
         @follow_contexts  = []               # Items that provide follow symbols to us
         @follow_sources   = []               # Itmes that provide late-bound follow contexts to us (anything that created us or an equivalent with shift())
         @followers        = nil
         @follow_sequences = nil
         @start_item       = false
         @signature        = self.to_s
         @production_sets  = production_sets
         
         follow_contexts.each do |item|
            add_follow_context( item )
         end
         
         @follow_sources = [ shifted_from_item ] unless shifted_from_item.nil?
         
         #
         # Caching support
         
         @closed                    = false
         @follow_contexts_finalized = false
      end       
      
      def hash()
         return @signature.hash
      end
      
      def eql?( rhs )
         return false unless rhs.is_an?(Item) 
         return self.signature == rhs.signature
      end
      
      def minimal_phrasing?()
         return @production.minimal_phrasing?
      end
      
      # 
      # rule_name()
      #  - returns the name of the underlying rule
      
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
      # leader()
      #  - returns the next Symbol from the mark
      
      def leader()
         return @production.symbols[@at]
      end
      
      
      # #
      # # recovery_dead_end?()
      # #  - returns true if error recovery should not voluntarily enter this production
      # 
      # def recovery_dead_end?()
      #    
      #    #
      #    # It's a dead end if it's a prefix expression.  ie. expression => - expression
      #    
      #    if symbols.length > 1 then
      #       potential_dead_end = true
      #       
      #       symbols[0..-2].each do |symbol|
      #          if !symbol.terminal? then
      #             potential_dead_end = false
      #             break
      #          end
      #       end
      #       
      #       if potential_dead_end then
      #          return true if !symbols[-1].terminal? and symbols[-1].name == @name
      #       end
      #    end
      #    
      #    return false
      # end
      
      





    #---------------------------------------------------------------------------------------------------------------------
    # Operations and Context Discovery
    #---------------------------------------------------------------------------------------------------------------------

    
      #
      # shift()
      #  - returns an Item like this one, but shifted one position to the right
      
      def shift()
         if complete? then
            return nil
         else
            return Item.new( @production, @at + 1, [] + @follow_contexts, @production_sets, self )
         end
      end
      
      
      #
      # close()
      #  - closes the Item for changes to context information
      #  - enables caching of context data
      #  - don't do this until all States in the Grammar are closed
      
      def close()
         @closed = true
      end
      
      
      #
      # follow_contexts()
      #  - returns the list of Items which provide context to us
      #  - avoid calling this before close(), as it is expensive; nor is it likely to be accurate
      
      def follow_contexts( loop_detector = nil )
         return @follow_contexts if @follow_contexts_finalized or !@closed
         
         #
         # Collect additional follow contexts from our sources.

         contexts_index = nil
         loop_detector  = Util::RecursionLoopDetector.new() if loop_detector.nil?
         complete = loop_detector.monitor(self.object_id) do
            
            #
            # We can't afford to reject signature-equivalent follow contexts, here, as they may have different 
            # follow contexts.  So, we eliminate duplicates on object_id.

            contexts_index = @follow_contexts.to_hash( :value_is_element ) { |item| item.object_id }
            @follow_sources.each do |follow_source|
               sourced_items = follow_source.follow_contexts( loop_detector )
               sourced_items.each do |sourced_item|
                  contexts_index[sourced_item.object_id] = sourced_item
               end
            end
         end

         #
         # Take additional actions as indicated by the monitor() result.  If complete is nil, we just looped.
         
         return [] if complete.nil?
         
         follow_contexts = contexts_index.values
         if @closed and complete then
            @follow_contexts = follow_contexts
            @follow_contexts_finalized = true
         end
         
         return follow_contexts
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
      
      def sequences_after_mark( length = 1, production_sets = nil, loop_detector = nil, skip_contexts = [] )
         return @sequences_after_mark unless @sequences_after_mark.nil? or @sequences_after_mark.length < length
         
         production_sets = @production_sets if production_sets.nil?
         assert( !production_sets.nil?, "you must supply a hash of ProductionSets to sequences_after_mark() when it is calculated" )

         loop_detector = Util::RecursionLoopDetector.new() if loop_detector.nil?
         completable = true

         #
         # Tools in hand, build the set.

         sequences_after_mark = nil
         complete = loop_detector.monitor(self.object_id) do

            #
            # Satisfy as much of the request as possible locally.  If the request is fully satisfied without going
            # to our follow contexts, all the better.
         
            local_symbols = rest()
            if local_symbols.length >= length then
               sequences_after_mark = SequenceSet.single( local_symbols )
            
            #
            # Otherwise, we have to go to our follow contexts for additional symbols.  We don't want the leader from
            # our contexts, as we ARE that leader symbol.
         
            else

               #
               # Given the following grammar fragment:
               #    expression  => id                                 
               #                => number                       
               #                => '(' expression ')'            
               #                => '-' expression                            {negation_expression}       {assoc=none}
               #                => expression '*' eol:ignore? expression     {multiplication_expression} {assoc=left}       
               #                => expression '/' expression                 {division_expression}       {assoc=left}  
               #                => expression '+' expression                 {addition_expression}       {assoc=left}  
               #                => expression '-' expression                 {subtraction_expression}    {assoc=left}  
               #                => expression '^' expression                 {something_expression}      {assoc=left}       
               #                => expression '%' expression                 {modulus_expression}        {assoc=left}  
               #                => string                                    {string_expression}         {assoc=none}
               #    
               # calculating the sequences_after_mark got incredibly expensive on Item:
               #   expression => id .
               #
               # This happened because that Item had 112 follow contexts, most of which had the same 112 follow contexts.
               # Because we don't store anything in any one of those mutually recursive contexts until they are all complete,
               # it was taking a very long time (200s) to calculate the set.  
               #
               # Truth be told, we don't need to check the same follow contexts more than once per outer call.  The optimization
               # is to pass in the list of follow contexts already being handled by upstream callers, then to remove them from 
               # the list of work we do.  Of course, by doing this, we add another potential incompleteness source, so we must
               # check this before caching the results.

               our_follow_contexts      = self.follow_contexts()
               relevant_follow_contexts = our_follow_contexts - skip_contexts
               skip_contexts            = skip_contexts + relevant_follow_contexts

               completable = false unless relevant_follow_contexts.length == our_follow_contexts.length
               
               sequence_sets = relevant_follow_contexts.collect do |context|
                  if context.nil? then
                     SequenceSet.end_of_input_set
                  else
                     set = context.sequences_after_leader( length - local_symbols.length, production_sets, loop_detector, skip_contexts )
                     completable = false unless context.sequences_after_mark_complete?
                     set
                  end
               end

               sequences_after_mark = SequenceSet.merge( sequence_sets ).prefix( local_symbols )
            end
         end
         
         #
         # Return appropriately, based on complete.  Note that complete.nil? indicates we tried to call ourselves.
         
         return SequenceSet.empty_set() if complete.nil?
         
         if @closed and completable and complete then
            @sequences_after_mark = sequences_after_mark
         end
         
         return sequences_after_mark
      end
      
      
      def sequences_after_mark_complete?()
         return !@sequences_after_mark.nil?
      end
      
      
      #
      # sequences_after_leader()
      #  - similar to sequences_after_mark, but skips the leader 
      #  - may return more symbols than you requested, but won't return fewer unless there really are none to be had
      
      def sequences_after_leader( length = 1, production_sets = nil, loop_detector = nil, skip_contexts = [] )
         sequences = sequences_after_mark( length + 1, production_sets, loop_detector, skip_contexts )
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
      # add_follow_source()
      #  - adds a follow source, which indicates an Item from which to include follow contexts at calculation time
      
      def add_follow_source( item )
         type_check( item, Item, true )
         
         unless @follow_sources.member?(item)
            @follow_sources << item
         end
      end
      
      
      #
      # add_follow_contexts_from( )
      #  - adds the follow contexts and follow sources from another Item
      #  - generally, this is used just before the other Item is trashed so as not to duplicate us
      
      def add_follow_contexts_from( item )
         item.follow_contexts.each do |context_item|
            add_follow_context( context_item )
         end
         
         item.follow_sources.each do |source_item|
            add_follow_source( source_item )
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
end  # module RCC

