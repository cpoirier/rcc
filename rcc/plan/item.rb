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
require "#{$RCCLIB}/util/trail_marker.rb"

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
      attr_reader   :follow_sources       # The Items from which we inherit additional follow contexts
      attr_accessor :start_item           # Indicates if the Item is a start item in its State
      attr_accessor :determinant_item     # Indicates if the Item is a determinant-only item in its State
      attr_reader   :signature            # A signature for this Item's primary data (production and mark) 
      attr_reader   :shifted_from_item
      
                                  
      def initialize( master_plan, production, at = 0, follow_contexts = [], shifted_from_item = nil )
         @master_plan      = master_plan
         @production       = production
         @at               = at
         @follow_contexts  = []               # Items that provide follow symbols to us
         @follow_sources   = []               # Items that provide late-bound follow contexts to us (anything that created us or an equivalent with shift())
         @followers        = nil
         @follow_sequences = nil
         @start_item       = false
         @signature        = "#{priority().to_s} " + @production.rule_name.signature + " => " + prefix().join(" ") + " . " + rest().join(" ")

         @follow_context_index = {}
         @follow_source_index  = {}
         follow_contexts.each do |item|
            add_follow_context( item )
         end
         
         if shifted_from_item.is_an?(Array) then
            shifted_from_item.each{ |i| add_follow_source(i) }
         else
            add_follow_source( shifted_from_item ) unless shifted_from_item.nil?
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
      
      def syntactic?()
         return @production.syntactic?
      end
      
      def lexical?()
         return @production.lexical?
      end
      
      def closed?()
         return @closed
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
      # starting?()
      #  - returns true if the underlying form is just beginning in this Item
      
      def starting?()
         return @at == 0
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
         if @production.syntactic? then
            return @priority if (defined?(@priority) and @priority.set?)
            return @production.priority
         else
            return -1
         end
      end
      
      
      #
      # priority=()
      #  - overrides the default priority for this Item and all Items made from it
      
      def priority=( value )
         @priority  = value
         @signature = self.to_s
      end




    #---------------------------------------------------------------------------------------------------------------------
    # Symbols
    #---------------------------------------------------------------------------------------------------------------------
    

      #
      # leaders()
      #  - returns a list of symbols you might legitimately encounter when processing our leader
      #  - leaders always come from this Item and no others
      #  - expands group leaders
      #  - includes discard symbols, if you ask nicely
      
      def leaders( include_discard = nil )
         return [] if complete?
         
         leaders  = @leaders.nil? ? @master_plan.symbols_for( leader() ) : @leaders
         @leaders = leaders if (@leaders.nil? and @closed)
         leaders  = include_discard ? leaders.merge(discards(include_discard)) : leaders

         return leaders
      end


      #
      # followers()
      #  - returns those symbols in this Item and its contexts that follow the leader
      #  - automatically expands groups and can optionally include discard

      def followers( include_discard = nil, into = nil, trail_marker = nil, covered_contexts = {}, covered_suppliers = {} )
         if @followers.set? then
            if into.nil? then
               return include_discard ? @followers.merge(discards(include_discard)) : @followers
            else
               @followers.each {|f| into[f] = true }
               discards(include_discard).each {|d| into[d] = true } if include_discard
               return into
            end
         end

         complete  = true
         followers = {}

         
         #
         # If we can satisfy it locally, do so.
         
         if followers_available? then
            @master_plan.symbols_for(@production.symbols[@at + 1]).each do |symbol|
               followers[symbol] = true
            end
         
         #
         # Otherwise, we go to our contexts.  However, we need to be smart about it.  First of all, we need to beware
         # of recursion loops.  We also want to shortcut as much as possible -- we shouldn't follow paths a parent
         # followers() call has already covered off, because no new information would be gained, and it would just
         # add a lot of time to the evaluation.  Instead, we use covered_contexts to keep from re-entering the exact same
         # follow context (by object_id), and we use covered_suppliers to keep from re-evaluating signature-equivalent 
         # follow contexts that can *directly* satisfy the request (ie. that don't have to go to their own follow 
         # contexts for symbols).  
         
         else
            trail_marker = Util::TrailMarker.new() if trail_marker.nil?            
            complete = trail_marker.enter(self.object_id) do
               follow_contexts().each do |fc|
                  if trail_marker.mark(fc.object_id) then
                     available = fc.followers_available?
                     if !available or (available and trail_marker.mark(fc.signature)) then
                        fc.followers( include_discard, followers, trail_marker )
                     end
                  end
               end
            end
            
            # coverable    = covered_contexts.empty?
            # completeable = true
            # 
            # complete = breadcrumbs.monitor(self.object_id) do
            #    contexts = follow_contexts.select do |fc|
            #       if covered_contexts.member?(fc.object_id) then
            #          completeable = false unless coverable
            #          false
            #       else
            #          covered_contexts[fc.object_id] = true
            #          true
            #       end
            #    end
            #    
            #    contexts.each do |fc|
            #       if covered_suppliers.member?(fc.signature) then
            #          completeable = false
            #       else
            #          covered_suppliers[fc.signature] = true if fc.followers_available?
            #          fc.followers( include_discard, into, loop_detector, covered_contexts, covered_suppliers )
            #       end
            #    end
            # end
            # 
            # complete = false unless completeable
         end

         
         #
         # Finish up.

         @followers = followers.keys if (@closed and complete)

         discards(include_discard).each {|d| followers[d] = true } if include_discard
         into.update(followers) if into.exists?
         
         return into.nil? ? followers.keys : into
      end
      

      #
      # followers_available?
      #  - returns true if this Item can directly satisfy a call to followers()
      
      def followers_available?()
         return @at + 1 < @production.length
      end
      
      
      #
      # shift_to_accept?
      
      def shift_to_accept?
         return false unless @at + 1 < @production.length
         symbol = @production.symbols[@at + 1]
         return symbol.name.eof?
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
      # syntactic_determinants()
      #  - transitively expands followers() returning a list of Tokens that can legally start any of them
      
      def syntactic_determinants( include_discard = nil )
         return @master_plan.syntactic_determinants_for( followers(include_discard) )
         #    
         #    
         #    loop_detector = Util::RecursionLoopDetector.new() if loop_detector.nil?
         #    local_symbols = {}
         #    completable   = false
         #    complete = loop_detector..monitor(self.object_id) do
         #       followers(include_discard).each do |symbol|
         #          if expanded_symbols.member?(symbol.name) then
         #             completeable = false
         #          else
         #             
         #          next if expanded_symbols.member?(symbol.name)
         #       end
         #    end
         # end
         # 
         
         return @syntactic_determinants
      end
      
      
      #
      # lexical_determinants()

      def lexical_determinants( include_discard = nil )
         return @master_plan.lexical_determinants_for( syntactic_determinants(include_discard) )
      end
      
      
      #
      # discards()
      
      def discards( type = :declared )
         case type
         when :effective
            return effective_discards()
         else
            return declared_discards()
         end
      end
      
      
      #
      # has_discards?()
      
      def has_discards?()
         return false unless syntactic?
         return !declared_discards().empty?
      end
      
      
      #
      # declared_discards()
      #  - for complete items, we draw the discards from the follow context (UNLESS the follow context
      #    would put us at eof, in which case we also include our own discards)
      #  - for starting items, we draw the discards from both this production and the follow context
      #  - for all others, local discard only
      
      def declared_discards( trail_marker = nil )
         if syntactic? then
            if complete? or starting? then
               return @declared_discards if @declared_discards.exists?

               discards = starting? ? [] + @production.discards() : []
               trail_marker = Util::TrailMarker.new() if trail_marker.nil?
               complete = trail_marker.enter(self.object_id) do
                  follow_contexts().each do |item|
                     if item.shift_to_accept? then
                        @production.discards().each do |symbol|
                           discards << symbol unless discards.member?(symbol)
                        end
                     else
                        item.declared_discards(trail_marker).each do |symbol|
                           discards << symbol unless discards.member?(symbol)
                        end
                     end
                  end
               end
            
               @declared_discards = discards if (@closed and complete)
               return discards
            else
               return @production.discards
            end
         else
            return []
         end
      end
      
      
      #
      # effective_discards()
      
      def effective_discards()
         return @effective_discards if @effective_discards.set?
         
         warn_bug( "Item.effective_discards() needs a LOT more testing" )

         effective_index = declared_discards().to_hash( true )
         if complete? then
            followers.each do |follower|
               next unless follower.symbolic?
               effective_index.delete( follower )
               follower.gateways.each do |gateway|
                  effective_index.delete( gateway )
               end
            end
         else
            leaders(false).each do |leader|
               next unless (leader.symbolic? and leader.producible?)
               effective_index.delete( leader )
            end
            
            leader().gateways.each do |gateway|
               effective_index.delete( gateway )
            end
         end
         
         effective_discards = effective_index.keys
         @effective_discards = effective_discards if @declared_discards.set?

         return effective_discards
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
            item = Item.new( @master_plan, @production, @at + 1, [] + @follow_contexts, self )
            item.priority = @priority if (defined?(@priority) and @priority.set?)
            return item
         end
      end
      
      
      #
      # transfer()
      #  - returns an Item just like this one
      
      def transfer()
         item = Item.new( @master_plan, production, @at, [] + @follow_contexts, self )
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
            item = Item.new( @master_plan, @production, @at - 1, [] + @follow_contexts, @follow_sources )
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
         @follow_context_index = nil
         @follow_source_index  = nil
         
         warn_bug( "recently changed add_follow_context() to use object_id -- is this correct?" )
         warn_bug( "recently changed add_follow_source() to use object_id -- is this correct?" )
      end
      
      
      #
      # follow_contexts()
      #  - returns the list of Items which provide context to us
      #  - avoid calling this before close(), as it is expensive; nor is it likely to be accurate
      
      def follow_contexts( trail_marker = nil )
         return @follow_contexts if (@follow_contexts_finalized or !@closed)
         
         #
         # Collect additional follow contexts from our sources.

         contexts_index = nil
         trail_marker   = Util::TrailMarker.new() if trail_marker.nil?
         complete = trail_marker.enter(self.object_id) do
            
            warn_bug( "are we properly detecting completeness here?" )
            
            #
            # We can't afford to reject signature-equivalent follow contexts, here, as they may have different 
            # follow contexts.  So, we eliminate duplicates on object_id.

            contexts_index = @follow_contexts.to_hash( :value_is_element ) { |item| item.object_id }
            @follow_sources.each do |follow_source|
               sourced_items = follow_source.follow_contexts( trail_marker )
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
      
      def determinants( include_discard = nil  )
         if syntactic? then
            return syntactic_determinants(include_discard)
         else
            return lexical_determinants(include_discard)
         end
      end
      
      
      # #
      # # followers()
      # #  - returns the list of terminals which may legitimately follow the leader()
      # #  - this is a dynamic calculation, and should not be relied upon until the entire state table is built!
      # #  - for now, this is k = 1
      # 
      # def followers()
      #    if syntactic? then
      #       return sequences_after_leader( 1 ).lookahead(@master_plan)
      #    else
      #       return sequences_after_leader( 1 ).lexical_lookahead(@master_plan)
      #    end
      # end
      # 
      # 
      # #
      # # production_la()
      # #  - returns the terminals that can follow our Production, were it to be complete
      # 
      # def production_la( k = 1 )
      #    assert( k == 1, "only k = 1 supported, presently" )
      #    return @production_la unless @production_la.nil?
      # 
      #    sequence_sets = @follow_contexts.collect do |context|
      #       if context.nil? then
      #          SequenceSet.end_of_input_set
      #       else
      #          set = context.sequences_after_leader( k )
      #       end
      #    end
      #    
      #    @production_la_sequences = SequenceSet.merge( sequence_sets )
      #    if syntactic? then
      #       @production_la = @production_la_sequences.lookahead( @master_plan )
      #    else
      #       @production_la = @production_la_sequences.lexical_lookahead( @master_plan )
      #    end
      #    
      #    return @production_la
      # end
      # 
      # 
      # #
      # # sequences_after_mark()
      # #  - transitively constructs all potential symbol sequences that can be seen looking "down" the rule 
      # #    from the mark and flowing into the lookahead, as necessary
      # #  - may return more symbols than you requested, but won't return fewer unless there really are none to be had
      # 
      # def sequences_after_mark( length = 1, loop_detector = nil, skip_contexts = {}, already_included = {} )
      #    return @sequences_after_mark unless @sequences_after_mark.nil? or @sequences_after_mark.length < length
      #    
      #    loop_detector = Util::RecursionLoopDetector.new() if loop_detector.nil?
      #    completable   = true
      #    top_level     = already_included.empty?
      #    debug         = context_variable(:debug)
      # 
      #    #
      #    # Tools in hand, build the set.
      # 
      #    sequences_after_mark = nil
      #    complete = loop_detector.monitor(self.object_id) do
      # 
      #       #
      #       # Satisfy as much of the request as possible locally.  If the request is fully satisfied without going
      #       # to our follow contexts, all the better.
      #    
      #       local_symbols = rest()
      #       if local_symbols.length >= length then
      #          sequences_after_mark = SequenceSet.single( local_symbols )
      #       
      #       #
      #       # Otherwise, we have to go to our follow contexts for additional symbols.  We don't want the leader from
      #       # our contexts, as we ARE that leader symbol.
      #    
      #       else
      # 
      #          #
      #          # Given the following grammar fragment:
      #          #    expression  => id                                 
      #          #                => number                       
      #          #                => '(' expression ')'            
      #          #                => '-' expression                            {negation_expression}       {assoc=none}
      #          #                => expression '*' eol:ignore? expression     {multiplication_expression} {assoc=left}       
      #          #                => expression '/' expression                 {division_expression}       {assoc=left}  
      #          #                => expression '+' expression                 {addition_expression}       {assoc=left}  
      #          #                => expression '-' expression                 {subtraction_expression}    {assoc=left}  
      #          #                => expression '^' expression                 {something_expression}      {assoc=left}       
      #          #                => expression '%' expression                 {modulus_expression}        {assoc=left}  
      #          #                => string                                    {string_expression}         {assoc=none}
      #          #    
      #          # calculating the sequences_after_mark got incredibly expensive on Item:
      #          #   expression => id .
      #          #
      #          # This happened because that Item had 112 follow contexts, most of which had the same 112 follow contexts.
      #          # Because we don't store anything in any one of those mutually recursive contexts until they are all complete,
      #          # it was taking a very long time (200s) to calculate the set.  
      #          #
      #          # Truth be told, we don't need to check the same follow contexts more than once per outer call.  The optimization
      #          # is to pass in the list of follow contexts already being handled by upstream callers, then to remove them from 
      #          # the list of work we do.  Of course, by doing this, we add another potential incompleteness source, so we must
      #          # check this before caching the results.
      # 
      #          our_follow_contexts = self.follow_contexts()
      # 
      #          relevant_follow_contexts = []
      #          our_follow_contexts.each do |fc|
      #             unless skip_contexts.member?(fc.object_id)
      #                relevant_follow_contexts << fc
      #                skip_contexts[fc.object_id] = true
      #             end
      #          end
      #                
      #          completable = false unless relevant_follow_contexts.length == our_follow_contexts.length
      # 
      #          #
      #          # But we can still do better.  Even with the above measures, our contexts are not necessarily unique.  
      #          # For items that can fully satisfy the sequences_after_mark() request with their own elements (ie. without
      #          # going to follow contexts), signature uniqueness is all that is necessary.  So, in these cases, we use the 
      #          # already_included index to avoid reprocessing items with signatures we've already handled.  Note that this 
      #          # does affect completeness, as we are passing the index down the chain.
      #          
      #          needed = length - local_symbols.length
      #          sequence_sets = relevant_follow_contexts.collect do |context|
      #             if context.nil? then
      #                SequenceSet.end_of_input_set
      #             else
      #                if needed <= context.length_of_rest(1) then
      #                   if already_included.member?(context.signature)
      #                      completeable = false unless top_level
      #                      next nil 
      #                   end
      #                   already_included[context.signature] = true
      #                end
      # 
      #                set = context.sequences_after_leader( needed, loop_detector, skip_contexts, already_included )
      #                completable = false unless context.sequences_after_mark_complete?
      #                set
      #             end
      #          end
      # 
      #          sequences_after_mark = SequenceSet.merge( sequence_sets.compact ).prefix( local_symbols )
      #       end
      #    end
      #    
      #    
      #    #
      #    # Return appropriately, based on complete.  Note that complete.nil? indicates we tried to call ourselves.
      #    
      #    return SequenceSet.empty_set() if complete.nil?
      #    
      #    if @closed and completable and complete then
      #       @sequences_after_mark = sequences_after_mark
      #    end
      #    
      #    return sequences_after_mark
      # end
      # 
      # 
      # def sequences_after_mark_complete?()
      #    return !@sequences_after_mark.nil?
      # end
      # 
      # 
      # #
      # # sequences_after_leader()
      # #  - similar to sequences_after_mark, but skips the leader 
      # #  - may return more symbols than you requested, but won't return fewer unless there really are none to be had
      # 
      # def sequences_after_leader( length = 1, loop_detector = nil, skip_contexts = {}, already_included = {} )
      #    sequences = sequences_after_mark( length + 1, loop_detector, skip_contexts, already_included )
      #    return sequences.slice( 1..-1 )
      # end
      # 
      
      
      #
      # length_of_rest()
      #  - returns the number of Symbols rest() will return
      
      def length_of_rest( offset = 0 )
         return @production.length - (@at + offset)
      end
      
      
      
      #
      # add_follow_context()
      #  - adds a follow context, which can be used when calculating lookahead 
      
      def add_follow_context( item )
         unless @follow_context_index.member?(item.object_id)
            @follow_contexts << item
            @follow_context_index[item.object_id] = item
         end
      end
      
      
      #
      # add_follow_source()
      #  - adds a follow source, which indicates an Item from which to include follow contexts at calculation time
      
      def add_follow_source( item )
         unless @follow_source_index.member?(item.object_id)
            @follow_sources << item
            @follow_source_index[item.object_id] = item
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
         return "#{priority().to_s} " + rule_name().description + " => " + prefix().join(" ") + " . " + rest().join(" ")
      end
      
      def display( stream = $stdout )
         stream.puts self.to_s
         # stream << self.to_s << "     >>>  " << self.followers.join("|") << "\n"
      end


     
   end # Item
   


end  # module Plan
end  # module RCC

