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
      
                                  
      def initialize( production, at = 0, follow_contexts = [], shifted_from_item = nil )
         @master_plan      = production.master_plan
         @production       = production
         @at               = at
         @follow_contexts  = []               # Items that provide follow symbols to us
         @follow_sources   = []               # Items that provide late-bound follow contexts to us (anything that created us or an equivalent with shift())
         @followers        = nil
         @follow_sequences = nil
         @start_item       = false
         @signature        = self.to_s
         
         follow_contexts.each do |item|
            add_follow_context( item )
         end
         
         if shifted_from_item.is_an?(Array) then
            @follow_sources = shifted_from_item
         else
            @follow_sources = [ shifted_from_item ] unless shifted_from_item.nil?
         end
         
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
      
      def generate_error_recoveries?()
         return @production.generate_error_recoveries?
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
      
      
      #
      # leadin()
      #  - returns the Symbol before the mark
      
      def leadin()
         if @at == 0 then
            return nil
         else
            return @production.symbols[@at-1]
         end
      end
      
      
      #
      # length()
      #  - returns the length of the underlying Production
      
      def length()
         return @production.length
      end


      #
      # symbols()
      #  - returns the full set of Production symbols
      
      def symbols()
         return @production.symbols
      end


      #
      # priority()
      #  - returns the priority for this Item
      
      def priority()
         return @priority if (defined?(@priority) and @priority.set?)
         return @production.priority
      end
      
      
      #
      # priority=()
      #  - overrides the default priority for this Item and all Items made from it
      
      def priority=( value )
         @priority  = value
         @signature = self.to_s
      end






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
            item = Item.new( @production, @at + 1, [] + @follow_contexts, self )
            item.priority = @priority if (defined?(@priority) and @priority.set?)
            return item
         end
      end
      
      
      #
      # transfer()
      #  - returns an Item like this one, but rewritten to have just shifted an additional symbol
      
      def transfer( symbol )
         production = @production.new_transfer_version( symbol, @at, @master_plan )
         item = Item.new( production, @at + 1, [] + @follow_contexts, self )
         item.priority = @priority if (defined?(@priority) and @priority.set?)
         return item
      end
      
      
      #
      # unshift()
      #  - returns an Item like this one, but shifted on position to the left
      #  - don't rely on the follow contexts for this -- they probably won't be correct!
      
      def unshift()
         if @at == 0 then
            return nil
         else
            item = Item.new( @production, @at - 1, [] + @follow_contexts, @follow_sources )
            item.priority = @priority if (defined?(@priority) and @priority.set?)
            return item
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
      
      def determinants( k = 1 )
         assert( k == 1, "only k = 1 supported, presently" )
         return sequences_after_mark(k).lookahead( @master_plan )
      end
      
      
      #
      # followers()
      #  - returns the list of terminals which may legitimately follow the leader()
      #  - this is a dynamic calculation, and should not be relied upon until the entire state table is built!
      #  - for now, this is k = 1
      
      def followers( loop_detection = nil )
         return sequences_after_leader( 1 ).lookahead(@master_plan)
      end


      #
      # production_la()
      #  - returns the terminals that can follow our Production, were it to be complete
      
      def production_la( k = 1 )
         assert( k == 1, "only k = 1 supported, presently" )
         return @production_la unless @production_la.nil?

         sequence_sets = @follow_contexts.collect do |context|
            if context.nil? then
               SequenceSet.end_of_input_set
            else
               set = context.sequences_after_leader( k )
            end
         end
         
         @production_la_sequences = SequenceSet.merge( sequence_sets )
         @production_la = @production_la_sequences.lookahead( @master_plan )
         
         return @production_la
      end
         
         
         

      
      
      #
      # sequences_after_mark()
      #  - transitively constructs all potential symbol sequences that can be seen looking "down" the rule 
      #    from the mark and flowing into the lookahead, as necessary
      #  - may return more symbols than you requested, but won't return fewer unless there really are none to be had
      
      def sequences_after_mark( length = 1, loop_detector = nil, skip_contexts = [] )
         return @sequences_after_mark unless @sequences_after_mark.nil? or @sequences_after_mark.length < length
         
         loop_detector = Util::RecursionLoopDetector.new() if loop_detector.nil?
         completable   = true

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
                     set = context.sequences_after_leader( length - local_symbols.length, loop_detector, skip_contexts )
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
      
      def sequences_after_leader( length = 1, loop_detector = nil, skip_contexts = [] )
         sequences = sequences_after_mark( length + 1, loop_detector, skip_contexts )
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
      #  - returns those Symbols from this Item that follow the mark
      
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
         base = "#{priority().to_s} " + rule_name().description + " => " + prefix().join(" ") + " . " + rest().join(" ")
      end
      
      def display( stream = $stdout )
         stream << self.to_s << "     >>>  " << self.followers.join("|") << "\n"
      end


     
   end # Item
   


end  # module Plan
end  # module RCC

