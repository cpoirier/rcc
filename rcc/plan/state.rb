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
require "#{$RCCLIB}/scanner/artifacts/name.rb"
require "#{$RCCLIB}/plan/item.rb"
require "#{$RCCLIB}/plan/actions/action.rb"
require "#{$RCCLIB}/plan/explanations/explanation.rb"
require "#{$RCCLIB}/plan/predicates/predicate.rb"
require "#{$RCCLIB}/util/ordered_hash.rb"
require "#{$RCCLIB}/util/sparse_array.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class State
 #  - a single state in the parser

   class State
      
      Name = Scanner::Artifacts::Name
      
      
      #
      # ::signature()
      #  - returns the signature for a set of start Items
      
      def self.signature( start_items )
         return start_items.collect{|item| item.signature}.sort.join("\n")
      end
      
      
      def self.start_state( master_plan, start_rule_name )
         state = new( master_plan, 0 )
         state.context_grammar_name = start_rule_name.grammar 
         
         start_productions = []
         start_productions << SyntaxProduction.start_production( start_rule_name )
         
         state.add_productions( start_productions )
         
         return state
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and construction
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :master_plan
      attr_reader   :signature
      attr_accessor :number
      attr_reader   :items
      attr_reader   :start_items
      attr_reader   :transitions
      attr_reader   :reductions
      attr_reader   :symbolic_actions
      attr_reader   :literal_actions
      attr_reader   :fallback_lexical_action
      attr_reader   :explanations
      attr_reader   :lookahead_explanations
      attr_reader   :recovery_predicates
      attr_accessor :context_grammar_name
      
      alias actions symbolic_actions
      
      def initialize( master_plan, state_number = 0, start_items = [], context_state = nil  )
         @master_plan             = master_plan              # I think this is self-explanatory ;-)
         @number                  = state_number             # The number of this State within the overall ParserPlan
         @items                   = []                       # All Items in this State
         @start_items             = []                       # The Items that started this State (ie. weren't added by close())
         @context_free            = true                     # If true, follow contexts are irrelevant
         @closed                  = false                    # A flag indicating that close() has been called
         @signature               = nil                      # A representation of this State that will be common to all mergable States
         @transitions             = {}                       # Symbol.name => State
         @reductions              = []                       # An array of complete? Items
         @queue                   = []                       # A queue of unclosed Items in this State
         @symbolic_actions        = {}                       # Symbol.name => Action
         @literal_actions         = nil                      # Symbol.name|CharacterRange => Action
         @fallback_lexical_action = nil                      # Action to use if no @literal_actions apply
         @lookahead_explanations  = nil                      # An InitialOptions Explanation, if requested
         @context_grammar_name    = context_state.nil? ? nil : context_state.context_grammar_name

         @item_index = {}       # An index used to avoid duplication of Items within the State
         start_items.each do |item|
            add_item( item )
         end
         
         @context_states = {}            # States that refer to us via transitions or reductions
         @context_states[context_state.number] = true unless context_state.nil?
         
         #
         # Recovery plan
         
         @recovery_predicates = {}  
         @used_to_states      = {}
      end
      
      attr_accessor :close_duration
      
      def context_free?()
         @context_free
      end
      

      
      #
      # provide_context()
      #  - wraps this State's context around your block
      
      def provide_context()
         Scanner::Artifacts::Name.in_grammar(@context_grammar_name) do
            yield( self )
         end
      end
      
      
      #
      # action_for()
      #  - properly handles action lookup for various types
      #  - returns the fallback reduce action for unknown symbolic determinants
      #  - returns nil for unknown literal determinants (as it indicates an error)
      
      def action_for( determinant )
         if context_free? then
            return @symbolic_actions[nil]
         else
            literal = nil
            name    = nil
            
            case determinant
            when Numeric
               literal = determinant
            when Name
               name    = determinant
            when NilClass
               # no op
            else
               if determinant.character? then
                  literal = determinant.character
               elsif determinant.eof? then
                  literal = -1
                  name    = determinant.type
               else
                  name    = determinant.type
               end
            end
            
            if literal.set? and found = @literal_actions[literal] then
               return found
            elsif @symbolic_actions.member?(name) then
               return @symbolic_actions[name]
            end
            
            if @symbolic_actions.member?(nil) then
               return @symbolic_actions[nil]
            end
         end

         return nil
      end
      
      
      #
      # default_action()
      
      def default_action()
         return @symbolic_actions[nil]
      end
      
      
      #
      # add_productions( )
      #  - adds all Productions in a ProductionSet to this state, as 0 mark Items
      
      def add_productions( production_set, context_item = nil )
         items = []
         production_set.each do |production|
            item = Item.new( @master_plan, production, 0, context_item )
            add_item( item )
            items << item
         end
         
         return items
      end
      
      
      #
      # add_contexts()
      #  - adds follow contexts to our start phrases, given a set of start Items that would otherwise
      #    be used to make an identical State
      
      def add_contexts( shifted_items, context_state )
         return if (@closed and @context_free)
         
         assert( shifted_items.length == @start_items.length, "you can only add contexts that match this State's start items!" )
         
         index = @start_items.to_hash(:value_is_element){|item| item.signature}

         shifted_items.each do |shifted_item|
            assert( index.member?(shifted_item.signature), "you can only add contexts that match this State's start items!" )
            
            index[shifted_item.signature].add_follow_contexts_from( shifted_item )
            index.delete( shifted_item.signature )
         end
         
         @context_states[context_state.number] = true
      end
      

      #
      # close()
      #  - completes the State by calculating the closure of the start items
      
      def close()
         @closed = true
         @signature = State.signature( @start_items )
         
         #
         # For this discussion, we'll use the following grammar (we'll dispense with quoting of terminals):
         #    S => E ;
         #
         #    E => V
         #      => num
         #      => ( E )
         #      => E * E
         #      => E / E
         #      => E + E
         #      => E - E
         #
         #    V => id
         #   
         # To close the State, we have to go through every Item and deal with any that lead with non-terminals.  We can't
         # parse non-terminals from the input stream directly -- we have to build the non-terminals from terminals first.  
         # So, in addition to those existing Items, we must transitively add Items to get to Productions that expect a
         # terminal next. 
         #
         # Yeah, okay, that was as clear as mud.  Maybe an example, huh?
         #
         # Let's say our State starts with one Item (where "." is the mark and the stuff at the end of the line is the 
         # inherited lookahead):
         # 1) E => ( . E )    $
         #
         # E, a non-terminal, is the next symbol to be read, so we get the ProductionSet for E:
         #    E => V
         #      => num
         #      => ( E )
         #      => E * E
         #      => E / E
         #      => E + E
         #      => E - E
         # 
         # We want to add each of these Productions to the State.  Because we are substituting in to an existing rule,
         # we'll use its follow symbols as the inherited lookahead for the new Items.  Bringing us to:
         # 2) E => ( . E )    $
         #    E => . V        )
         #    E => . num      )
         #    E => . ( E )    )
         #    E => . E * E    )
         #    E => . E / E    )
         #    E => . E + E    )
         #    E => . E - E    )
         #
         # Now we have several new Items with leading non-terminals, specifically V and E (4 times).  Now, we must expand 
         # each in turn.  However, we would like to avoid adding multiple identical expansions of any Production to the
         # State, as we that just unnecessarily complicates things.  So, instead, when we find a equivalent Item already 
         # present, we simply add the lookahead of our would-be new Item the existing Item.  
         #
         # We'll do this one iteratively so you can see it being built.
         #
         # 3) Expand E => . V with all productions of V
         #    E => ( . E )    $          
         #    E => . V        )
         #    E => . num      )   
         #    E => . ( E )    )
         #    E => . E * E    )    
         #    E => . E / E    )
         #    E => . E + E    )
         #    E => . E - E    )
         #    V => . id       )
         #
         # 4) Expand E => . E * E with all productions of E
         #    E => ( . E )    $          
         #    E => . V        )|*
         #    E => . num      )|*   
         #    E => . ( E )    )|*
         #    E => . E * E    )|*  
         #    E => . E / E    )|*
         #    E => . E + E    )|*
         #    E => . E - E    )|*
         #    V => . id       )
         #
         # 5) Expand E => . V of E => . E * E with all productions of V
         #    E => ( . E )    $          
         #    E => . V        )|*
         #    E => . num      )|*   
         #    E => . ( E )    )|*
         #    E => . E * E    )|*  
         #    E => . E / E    )|*
         #    E => . E + E    )|*
         #    E => . E - E    )|*
         #    V => . id       )|*
         #
         # 5) Expand E => . E / E with all productions of E
         #    E => ( . E )    $          
         #    E => . V        )|*|/
         #    E => . num      )|*|/   
         #    E => . ( E )    )|*|/
         #    E => . E * E    )|*|/
         #    E => . E / E    )|*|/
         #    E => . E + E    )|*|/
         #    E => . E - E    )|*|/
         #    V => . id       )|*
         #
         # 6) Expand E => . V of E => . E / E with all productions of V
         #    E => ( . E )    $          
         #    E => . V        )|*|/
         #    E => . num      )|*|/   
         #    E => . ( E )    )|*|/
         #    E => . E * E    )|*|/
         #    E => . E / E    )|*|/
         #    E => . E + E    )|*|/
         #    E => . E - E    )|*|/
         #    V => . id       )|*|/
         #
         # Rinse and repeat for E => . E + E and E => E - E -- yield versions 7, 8, 9, and, finally:
         # 
         # 10)E => ( . E )    $          
         #    E => . V        )|*|/|+|-
         #    E => . num      )|*|/|+|-   
         #    E => . ( E )    )|*|/|+|-
         #    E => . E * E    )|*|/|+|-
         #    E => . E / E    )|*|/|+|-
         #    E => . E + E    )|*|/|+|-
         #    E => . E - E    )|*|/|+|-
         #    V => . id       )|*|/|+|-
         #
         # Now, that is *conceptually* what we are doing.  However, we are trying to build LALR(1) states, not LR(1) states.  
         # The difference is that we attempt to merge States within the overall ParserPlan that are identical except for 
         # the inherited lookahead, just like we did for the Items within the State.  This means that our lookahead set is 
         # constantly growing -- each time another State is merged with this one, the start items inherit more lookahead 
         # options, and those lookahead symbols must then propogate to all the Items in this State.  Which is a pain in the 
         # ass.  Not to mention expensive.  So, instead of doing all this work again and again, we are going to defer the 
         # calculation of ALL lookahead until after all the States have been built.  Instead of accumulating lookahead 
         # symbols, we'll accumulate links to Items which can provide lookahead symbols in each Item.  We'll call these 
         # context Items "follow contexts".
         #
         # For instance, in version 2 (above), all the added Productions of E inherited their lookahead from the first 
         # Item in the set.  So instead of copying lookahead symbols, we add Item 1 as a follow context to all of those 
         # new Items.  In version 3, V => id was added to the State and inherited its lookahead from Item 2 (E => . V), 
         # so we now add Item 2 as a follow context to the new Item.  In version 4, we re-add the Productions of E, this
         # time expanding E => . E * E, so we add Item 5 as follow context to all the (existing) Items we would have merged
         # lookahead into.  And so on.
         #
         # Now, apart from simplifying our merging work, linking Items into a follow context graph (as we are doing) has
         # a significant benefit: we are no longer limited to k = 1 for our lookahead size.  Each lookahead context can 
         # provide any number of lookahead terminals through transitive closure on its follow symbols and those it inherits
         # from its contexts.  We can then produce first and follow sets that fully predict the valid lookahead to any
         # k.  There will be computational cost, of course, but we will need no additional code.  See Item.follow_sequences()
         # and Item.followers() for more details.  
         #
         # For now (and at long last), let's just build the damned thing.
         
         reprioritize = false
         leadin = @start_items[0].leadin
         if leadin.set? and leadin.symbolic? and leadin.lexical? then
            reprioritize = true
            @start_items.each do |start_item|
               if start_item.complete? then
                  reprioritize = false 
                  break
               elsif start_item.leadin != leadin then
                  reprioritize = false
                  break
               end
            end
         end
         
         added_by_context = {}
         until @queue.empty? 
            item = @queue.shift
            
            #
            # We only have (further) work to do if the Item has a Production leader.  Our add_productions()
            # subsystem deals with adding/merging Items, as appropriate.

            if item.complete? then
               @reductions << item
            else

               item.leaders().each do |leader|
                  next unless (leader.symbolic? and leader.producible?)
                  
                  name = leader.name
                  if @master_plan.production_sets.member?(name) then
                     added_items = add_productions( @master_plan.production_sets[name], item )
                     
                     if reprioritize then
                        added_items.each do |added_item|
                           next unless added_item.production.syntactic?
                           added_by_context[added_item] = [] unless added_by_context.member?(added_item)
                           added_by_context[added_item] << item unless added_by_context[added_item].member?(item)
                        end
                     end
                  else
                     nyi "error handling for missing reference name [#{name}]"
                  end
               end
            end
         end
         
         if reprioritize then
            added_by_context.each do |added_item, context_items|
               unique_contexts = context_items.collect{|item| item.production.ast_class}.uniq
               next unless unique_contexts.length == 1
               added_item.priority = context_items[0].priority 
            end
         end
      end
      
      
      #
      # enumerate_syntactic_transitions()
      #  - calls your block once for every potential syntactic production transition from this State
      #  - passes in the transition Symbol and the shifted Items it results in
      
      def enumerate_syntactic_transitions()
         enumerate_transitions(:syntactic) do |symbol_name, shifted_items|
            yield( symbol_name, shifted_items )
         end
      end
      
      
      #
      # enumerate_lexical_transitions()
      #  - calls your block once for every potential lexical production transition from this State
      #  - passes in the transition Symbol or character range and the shifted Items it results in
      
      def enumerate_lexical_transitions()
         enumerate_transitions(:lexical) do |symbol_name_or_range, shifted_items|
            yield( symbol_name_or_range, shifted_items )
         end
      end


      #
      # add_transition()
      #  - registers a transition from this to another for the specified Symbol name
      
      def add_transition( symbol_name, transition_state )
         @transitions[symbol_name] = transition_state
      end
      
            
      #
      # close_items()
      #  - marks all Items as closed
      #  - call this after you have constructed all States, but before you expect correct follow sequences
      
      def close_items()
         @items.each do |item|
            item.close()
         end
      end
      
      
   


    #---------------------------------------------------------------------------------------------------------------------
    # Action planning
    #---------------------------------------------------------------------------------------------------------------------

      #
      # compile_syntactic_actions()
      #  - plans out Actions for all syntactic actions
      #  - may add new Items to the State for necessary lexical Productions
      #  - unless you know better, you should follow this activity with lexical handling, by building lexical
      #    transitions and then lexical actions
      
      def compile_syntactic_actions( state_table, estream = nil )
         explain = @master_plan.produce_explanations?
         
         present_determinants    = {}
         additional_determinants = {}
         

         #
         # Step 1: Sort items into action categories: shift and reduce.  There are no discards, yet -- we
         # have to add them; and we skip lexical productions altogether.

         shift_items    = []
         reduce_items   = []

         @items.each do |item|
            next unless item.syntactic?
            
            if item.complete? then
               reduce_items << item
            else
               shift_items  << item
            end
         end


         #
         # Step 2: Set up discards.  Note that we NEVER consider the discard before a non-token leader 
         # in our processing: Item takes care of propagating those discards to the proper place.
         #
         # There are a variety of possibilities:
         #
         # 1) All items share the same discards.  In this case, we need only add the appropriate token 
         #    productions to the state and a Discard action for each.  
         #
         # 2) We could have items with different effective discards (this case includes the use of gateway
         #    expressions to preclude one or more discards on a particular item).  These items can coexist 
         #    with each other, but not with any un-shared discard actions.  When an unshared discard is 
         #    necessary, we must move to a new state that does not include those incompatible items.  This 
         #    will require altering the state table.
         # 
         # 3) One of our leaders could *be* an explicit use of one of our discard symbols.  This is a similar
         #    to case 1), but requires different actions.  In this case, we will set up backtracking, first 
         #    to shift the symbol (moving to an existing state); then, if it fails to commit, we discard the 
         #    symbol and retry.  However, after the discard, the explicit shift item is no longer valid.  As 
         #    a result, we must create a new state to accept the discard result, with only those items that
         #    expected the discard.
         # 
         # 4) The discards for our shiftable items might not be discardable for our reduceable items.  If 
         #    so, we can't just discard something and return to the same state.  There are two possibilities,
         #    but both require that we create additional states to handle the aftermath.  First, one of our
         #    discards could be a determinant for a reduce item.  If so, we must try the reduce first, and
         #    see how it goes.  Only if it fails can we then try the discard, but in so doing, the reduce
         #    is eliminated from consideration.  And second, the discard might not be a determinant for the
         #    reduce, in which case no backtracking is necessary, but we must end up in a state that doesn't
         #    include the reduce item.
         #
         # 5) The discards for our reduceable items might conflict with our leaders.  This is essentially 
         #    a shift/reduce conflict, but we must prioritize the shift over the reduce, as the determinant
         #    is positionally "closer" than the next symbol in the reduce item's context.
         #
         # 6) The discards for our reducable items might include symbols not discarded by our shiftable 
         #    items.  Fortunately, this is a simple case -- those symbols unique to the reduceable items
         #    become determinants for the reduce.  No special handling is required.
         #
         # Finally, we may have some combination of these conditions in the same state.  This means we may
         # have to unroll things in multiple directions.  Yay.  :-|

         unless shift_items.empty?
            once do
               
               #
               # Gather information on our discard options.  We'll collect a set of common discards (for which
               # we can immediately create local Discard actions), actionable discards (any not in common_discards
               # require a lot more work), and reduce-only discards (which inform our determinants).
               #
               # NOTE that we never consider discard before non-tokens.  Discard is a lexical problem, and for
               # syntactic elements, it becomes another Item's problem.
               
               local_discards       = {}
               common_discards      = nil
               actionable_discards  = {}
               reduce_only_discards = {}
               
               [shift_items, reduce_items].each do |item_set|
                  item_set.each do |item|
                     next if (!item.complete? and item.leaders.select{|symbol| symbol.refers_to_token?}.empty?)
                     
                     intersection = {}
                     initializing = false
               
                     if common_discards.nil? then
                        common_discards = {}
                        initializing    = true
                     end
                  
                     item.effective_discards.each do |discard|
                        local_discards.accumulate( discard, item ) unless item.complete?
                        
                        if item.complete? and (reduce_only_discards.member?(discard) or !actionable_discards.member?(discard)) then
                           reduce_only_discards.accumulate( discard, item )
                        else
                           actionable_discards.accumulate( discard, item )
                           
                           if initializing then
                              common_discards[discard] = true
                           else
                              intersection[discard] = true if common_discards.member?(discard)
                           end
                        end
                     end
                  
                     common_discards = intersection unless initializing
                  end
               end
               
               
               #
               # Add all local discards to the state for lexing purposes.
               
               local_discards.each do |discard, context_items|
                  production_set = @master_plan.production_sets[discard.name]
                  context_items.each do |item|
                     add_productions( production_set, item )
                  end
               end
               
               
               #
               # Any common discards can immediately be converted to actions.  By definition, common discards
               # will never be determinants of our reduce items.  Once processed, we can eliminate them from 
               # the actionable_discards.
               
               common_discards.keys.each do |discard|
                  warn_nyi( "how do we explain discard decisions?" )
                  @symbolic_actions[discard.name] = Actions::Discard.new( discard.name )
                  actionable_discards.delete( discard )
               end
               
               
               #
               # If there are no other actionable discards, we're done.
               
               if actionable_discards.empty? then
                  additional_determinants.update( reduce_only_discards )
                  break
               end
               
               
               #
               # If we are still here, we next have to plan for one or more new states.  But we'll need one more
               # set of information -- the list of reduce determinants that conflict with our actionable_discards.
               # These determinants will also cause new state changes.

               discarded_determinants = {}
               reduce_items.each do |item|
                  item.determinants.each do |determinant|
                     if actionable_discards.member?(determinant) then
                        discarded_determinants.accumulate( determinant, item )
                     end
                  end
               end
               
               
               #
               # Okay, so now we need to figure out our plans.  We deal with things using backtracking,
               # so along each vector, we need to organize things by action category: 0 or more reduce items (from
               # the discarded_determinants), followed by 0 or more shift items (due to a discard used as leader), 
               # followed by 0 or more discard items (everything else that wants the symbol discarded).  The first 
               # two sets require no additional states.  The last does, and the discard action created for it will 
               # include a goto to that new state.
               
               discard_plans = {}
               
               discarded_determinants.each do |determinant, items|
                  DiscardPlan.instance(discard_plans, determinant.name).reduce_items.concat( items )
               end
               
               shift_items.each do |item|
                  item.leaders.each do |leader|
                     if actionable_discards.member?(leader) then
                        DiscardPlan.get_instance(discard_plans, leader.name).shift_items << item
                     end
                  end
               end
               
               actionable_discards.each do |discard, items|
                  DiscardPlan.instance(discard_plans, discard.name).discard_items.concat( items )
               end
               
               
               #
               # Finally, adjust the state table for discard processing and generate our actions.
               
               discard_plans.each do |determinant_name, discard_plan|
                  @symbolic_actions[determinant_name] = discard_plan.compile( self, state_table )
               end
            end
         end


         #
         # Step 3: If we have both shift and reduce items, we may need to add additional lexical items to 
         # this State.
         #
         # Generally speaking, we ignore determinants for reduce, choosing instead to leave any errors up 
         # to the next shift to find.  This simplifies the overall state table, as we don't have to add a 
         # potentially long list of lexical items to every state.  It also makes streaming parses more 
         # practical -- in states where reduce is the only possible action (which tends to happen at the 
         # end of statements and such), we don't have to read ahead before doing the reduce.  
         #
         # However, when a state has a shift/reduce conflict, we can't completely ignore determinants for
         # the reduce item.  This is because lexing is context-sensitive.  Let's say we had the following
         # shift/reduce conflict:
         #   e => e '!' e .
         #   e => e . '!' e
         # 
         # but the reduce item's context item is:
         #   s => . e '!!' eol
         #
         # Now we have a problem.  Lexes are always longest-match, so the user will be expecting us to 
         # tell the difference between two '!' and one '!!'.  However, without the determinants for the 
         # reduce item, we'll stop lexing after the first '!', which will result in an error down the line.
         # 
         # So, in order to avoid this, we will get the lexical determinants for the reduce items, and add
         # to this state any of them that overlap the existing lexical items.  We don't need to 
         # include any that don't conflict with our existing determinants, as we'll fall back to the reduce
         # operation anyway, if the shifts fail.
         
         unless shift_items.empty?
            
            #
            # Start by getting the existing lexical determinants from our items.  As we are (obviously) in
            # a state with syntactic items, all lexical items will be at position 0.  Further, because close()
            # has already been called, the natural lexical items have already been fully expanded.  Therefore,
            # we'll collect vectors only where a character range is leader.
            
            vectors = CharacterRange.new()
            @items.each do |item|
               next unless item.lexical?
               next unless item.leader.refers_to_character?

               vectors.add( item.leader )
               present_determinants[item.production.name] = true
            end

            #
            # Next, start adding items, updating vectors as we go.
            
            reduce_items.each do |item|
               item.determinants.each do |determinant|
                  additional_determinants.accumulate( determinant, item ) unless present_determinants.member?(determinant.name)
               end
            end
            
            additional_determinants.each do |determinant, context_items|
               character_range = @master_plan.lexical_determinants_for(determinant)
               if character_range.overlaps?(vectors) then
                  vectors.add( character_range )
                  present_determinants[determinant.name] = true

                  production_set = @master_plan.production_sets[determinant.name]
                  context_items.each do |item|
                     add_productions( production_set, item )
                  end
               end
            end
         end
         
         
         #
         # Step 4: Deal with shift commits.  We do this by merging all potential shift commits down to 
         # a single action for any shift.  If there is only one, then we do it.  If there are multiples
         # and they are not the same, we do nothing.
         
         shift_commits_by_leader = {}
         shift_items.each do |item|
            shift_commits_by_leader.accumulate( item.leader.name, item.leader.commit_point )
         end

         shift_commits_by_leader.each do |symbol_name, shift_commits|
            if shift_commits.uniq.length == 1 then
               shift_commits_by_leader[symbol_name] = shift_commits[0]
            else
               shift_commits_by_leader[symbol_name] = nil
            end
         end
         
      
         #
         # Step 5: Next, group our shift and reduce items by determinant.  We don't need to worry too much 
         # about the reduce determinants -- only those that are lexible in this state.
         
         options = {}
         
         shift_items.each do |item|
            item.leaders.each do |leader|
               options.accumulate( leader.name, item )
            end
         end
         
         reduce_items.each do |item|
            item.determinants.each do |determinant|
               next unless present_determinants.member?(determinant.name)
               options.accumulate( determinant.name, item )
            end
         end
         
         @lookahead_explanations = Explanations::InitialOptions.new(options) if explain

         
         #
         # Step 6: Generate a single action for each determinant.
         
         recovery_data = {}
         options.each do |symbol_name, items|

            explanations = []
            in_play      = []
            discarded    = []

            if items.length == 1 then
               item = items[0]
               in_play      << item
               explanations << Explanations::OnlyOneChoice.new( item ) if explain
            else

               #
               # If there are multiple options, we consider the highest priority shift (a shift/shift conflict 
               # for the same symbol goes to the same State -- but we need the valid production list, to ensure
               # that the forward States don't take liberties) and the highest priority reduce.  We consider
               # *nothing* (reduce or shift) after the highest priority reduce, as we don't want to risk doing
               # stupid things.  We tolerate as much ambiguity as might be useful, and no more.

               sorted = items.sort do |lhs, rhs|
                  if lhs.priority == rhs.priority then
                     lhs.complete? ^ rhs.complete? ? (lhs.complete? ? -1 : 1) : 0
                  else
                     lhs.priority <=> rhs.priority
                  end
               end

               reduce_priority = 10000000000
               sorted.each do |item|
                  if item.priority > reduce_priority then    # priority 1 is higher than priority 2
                     in_play << item
                  elsif item.complete? then
                     in_play << item
                     reduce_priority = item.priority
                  else
                     in_play << item
                  end
               end

               #
               # At this point, in_play contains 0 or more high priority shifts followed by a set
               # of 0 or more shifts and reduces at the same priority.  We have to look at that 
               # second set (if present) and apply associativity rules.

               keep_set  = []
               assoc_set = []

               in_play.each do |item|
                  if item.priority < reduce_priority then    # priority 1 is higher than priority 2
                     keep_set << item
                  else
                     assoc_set << item
                  end
               end

               unless assoc_set.empty?
                  assoc_shifts     = assoc_set.select{ |item| !item.complete? }
                  assoc_reductions = assoc_set.select{ |item| item.complete?  }
                  to_delete        = []

                  #
                  # Identify any reductions that meet certain global requirements.

                  unless assoc_shifts.empty? and keep_set.empty?
                     assoc_reductions.each do |reduction|
                        case reduction.production.associativity
                        when :right

                           #
                           # We can immediately eliminate any right-associative reductions if there are any equal or higher-priority 
                           # shifts.  We would definitely eliminate a right-assoc reduction in the presence of any equal priority shift, 
                           # so why wouldn't we do the same for higher priority shifts?

                           to_delete << reduction
                           explanations << Explanations::RightAssocReduceEliminated.new( keep_set.empty? ? assoc_shifts[0] : keep_set[0], reduction ) if explain

                        when :left

                           #
                           # We can eliminate any left-associative reductions that are lower priority than one or more of
                           # our shifts and that don't interact with the shifts for backtracking purposes.  

                           unless keep_set.empty?
                              delete_worthy = true
                              keep_set.each do |shift|
                                 prefix = shift.prefix
                                 if reduction.length <= prefix.length then
                                    if reduction.symbols == prefix.slice(-reduction.length..-1) then
                                       delete_worthy = false 
                                    end
                                 end
                              end

                              if delete_worthy then
                                 to_delete << reduction
                                 explanations << Explanations::LeftAssocReduceEliminated.new( reduction, keep_set ) if explain
                              end
                           end
                        end
                     end
                  end

                  #
                  # Delete anything we've identified.

                  to_delete.each do |reduction|
                     assoc_set.reject!{ |item| item.object_id == reduction.object_id }
                  end

                  #
                  # If there are any reduces left, check them against the assoc_shifts.

                  assoc_reductions.each do |reduction|
                     assoc_shifts.each do |shift|
                        case reduction.production.associativity
                           when :none
                              warn_nyi( "nonassociativity" )
                              # eliminated_reductions << reduction
                              # error_actions         << Actions::NonAssociativityViolation.new( shift, reduction )
                              # explanations          << Explanations::NonAssociativityViolation.new( shift, reduction ) if explain
                           when :left
                              assoc_set.reject!{ |item| item.object_id == shift.object_id }
                              explanations << Explanations::LeftAssocReduceEliminatesShift.new( reduction, shift ) if explain
                           else
                              # already done
                        end
                     end
                  end
               end

               in_play = keep_set + assoc_set
            end

            #
            # Collect the set of valid productions that can be produced if using backtracking.  This 
            # is the list of shift productions we try *before* any reductions.

            valid_productions = []
            in_play.each do |item|
               next if item.complete?
               valid_productions << item.production
            end

            #
            # Next, convert the in_play items to actions.

            shift_created   = false
            actions         = []
            attempt_span    = 0
            last_is_longest = nil
            in_play.each do |item|
               if item.complete? then
                  if item.length > attempt_span then
                     attempt_span = item.length
                     last_is_longest = item.production.ast_class
                  else
                     last_is_longest = nil unless item.production.ast_class == last_is_longest
                  end

                  actions << Actions::Reduce.new( item.production )
                  explanations << actions[-1]
               elsif symbol_name.eof? then
                  actions << Actions::Accept.new( item.production )
                  explanations << actions[-1]
               else
                  length = item.prefix.length
                  if length > attempt_span then
                     attempt_span = length
                     last_is_longest = item.production.ast_class
                  else
                     last_is_longest = nil unless item.production.ast_class == last_is_longest
                  end

                  if !shift_created then
                     actions << Actions::Shift.new( symbol_name, @transitions[symbol_name], valid_productions, shift_commits_by_leader[item.leader.name] )
                     shift_created = true
                     explanations << actions[-1]
                  end
               end
            end


            #
            # Create a single action for this symbol.

            case actions.length 
               when 0 
                  options.each do |symbol_name, items|
                     puts "#{symbol_name.description}:"
                     items.each do |item|
                        puts "   #{item.signature}"
                     end
                  end

                  bug "what the hell does this mean?"
               when 1
                  @symbolic_actions[symbol_name] = actions[0]
               else
                  explanations << Explanations::BacktrackingActivated.new( actions ) if explain
                  @symbolic_actions[symbol_name] = Actions::Attempt.new( actions, attempt_span, last_is_longest.set? )
            end

            #
            # Finish up.

            bug( "wtf?" ) if explanations.empty?
            @symbolic_actions[symbol_name].explanations = explanations if explain
            recovery_data[symbol_name] = in_play
         end
         
         
         #
         # Step 7: Generate a catch-all action, if there are any reduce items.
         
         unless reduce_items.empty?
            if reduce_items.length == 1 then
               @symbolic_actions[nil] = Actions::Reduce.new( reduce_items[0].production )
            else
               attempt_span    = 0
               last_is_longest = nil

               reduce_items.each do |item|
                  if item.length > attempt_span then
                     attempt_span = item.length
                     last_is_longest = item.production.ast_class
                  else
                     last_is_longest = nil unless item.production.ast_class == last_is_longest
                  end
               end

               @symbolic_actions[nil] = Actions::Attempt.new( reduce_items.collect{|item| Actions::Reduce.new(item.production)}, attempt_span, last_is_longest.set? )
            end
         end
         

         #
         # Step 8: Generate a recovery plan for the state.

         warn_bug( "generate_recovery_plan() has been disabled until we know what to do with it" )
         #generate_recovery_plan( recovery_data )

      end
      

      #
      # compile_lexical_actions()
   
      def compile_lexical_actions( estream = nil )
         explain = @master_plan.produce_explanations?
         literal_action_lists = CharacterMap.new()
         
         
         #
         # Step 1: Classify our items into sets: read, continue, group, and tokenize.  
         
         read_items     = []
         continue_items = []
         group_items    = []
         tokenize_items = []
         
         @items.each do |item|
            next unless item.lexical?
            
            if item.complete? then
               if item.production.tokenizeable? then
                  tokenize_items << item
               else
                  group_items << item
               end
            else
               if item.leader.refers_to_character? then
                  read_items << item
               else
                  continue_items << item
               end
            end
         end

         
         #
         # Step 2: Continue items are easy -- they always are used to shift a group, and they are always the
         # only choice, as we take longest match with lexical stuff.  Just add a @symbolic_action for them.
         
         continue_items.each do |item|
            group_name = item.leader.name
            next if @symbolic_actions.member?(group_name)
            @symbolic_actions[group_name] = Actions::Continue.new( group_name, @transitions[group_name] )
         end
         
         
         # 
         # Step 3: For literal processing, read actions are of the highest priority, as we want longest match.  
         # And seeing how enumerate_transitions() has already done all the math (ie. dealt with any overlap), we'll 
         # just work directly from @transitions. 
         
         read_actions_by_to_state = {}
         @transitions.each do |character_range, to_state|
            next unless character_range.is_a?(CharacterRange)
            
            if read_actions_by_to_state.member?(to_state.number) then
               read_actions_by_to_state[to_state.number].character_range.add( character_range )
            else
               read_actions_by_to_state[to_state.number] = Actions::Read.new( character_range, to_state )
            end
            
            literal_action_lists.merge_data( read_actions_by_to_state[to_state.number], character_range )
         end


         #
         # Step 4: For group and tokenize items, we use follow characters to determine if we are in valid state.  We'll 
         # generate actions for everything, then sort out what we'll keep later.
         
         group_items.each do |item|
            valid_follow_characters = item.determinants(:effective)
            literal_action_lists.merge_data( Actions::Group.new(item.production), valid_follow_characters )
         end
         
         tokenize_items.each do |item|
            valid_follow_characters = item.determinants(:effective)
            literal_action_lists.merge_data( Actions::Tokenize.new(item.production), valid_follow_characters )
         end


         #
         # Step 5: Now, we have to merge down all our literal actions to a single Action for any particular character 
         # code.  Read actions always win, as we want longest match when lexing.  Group actions win over Tokenize 
         # actions, for the same reason.  If there are two or more Group actions for a particular determinant, or two 
         # or more Tokenize actions for a particular determinant, we enable backtracking and try the most specific option 
         # first.
         
         @literal_actions = CharacterMap.new()
         literal_action_lists.each do |character_range, potential_actions|
            
            first_action = potential_actions.shift
            
            #
            # If the first action is a Read action, our course is clear.
            
            if first_action.is_a?(Actions::Read) then
               @literal_actions[character_range] = first_action
            
            
            #
            # Otherwise, we might have multiple options of the same type that we need to process.
               
            else
            
               selected_actions = [first_action]
               potential_actions.each do |action|
                  break unless action.is_a?(first_action.class)
                  selected_actions << action
               end
            
               if selected_actions.length == 1 then
                  @literal_actions[character_range] = first_action
               else

                  #
                  # Collect the backtracking criteria.
                  
                  attempt_span    = 0
                  last_is_longest = false
                  selected_actions.each do |action|
                     production = action.by_production
                     
                     if production.length > attempt_span then
                        attempt_span    = production.length
                        last_is_longest = true
                     else
                        last_is_longest = false
                     end
                  end
                  
                  #
                  # Sort the set into a reasonable order.  We prefer long matches over short ones.  If they are
                  # the same length, we prefer more-specific character ranges to less-specific ones.  If we are
                  # comparing symbols to character_ranges, the symbol wins.
                  
                  selected_actions.sort! do |a, b|
                     ap = a.by_production
                     bp = b.by_production
                     
                     if ap.length == bp.length then
                        if ap.symbols[-1].is_a?(Plan::Symbol) then 
                           -1
                        elsif bp.symbols[-1].is_a?(Plan::Symbol) then
                           1
                        else
                           ap.symbols[-1].length <=> bp.symbols[-1].length
                        end
                     else
                        bp.length <=> ap.length 
                     end
                  end

                  @literal_actions[character_range] = Actions::Attempt.new( selected_actions, attempt_span, last_is_longest )
               end
            end
         end

         
         #
         # Step 6: As we are done with our literal actions, make them a little faster to use.
         
         @literal_actions = @literal_actions.close( true )
      end


    
    
    


    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "State"
      end

      
      #
      # display()
      #  - dumps a formatted summary of the State and its data
      #  - you can supply stream variables to control the content:
      #     :state_context  => nil, :determinants   - shows legal lookahead
      #                     => :determinants_plus   - shows legal lookahead plus 2 additional follow symbols
      #                     => :follow_contexts     - shows the list of follow contexts for this state
      #                     => :raw_follow_contexts - shows the list of follow contexts and follow sources
      #     :state_complete => true                 - adds a full transition map, reductions, and recovery plans 
      #                                               to the output

      def display( stream = $stdout )
         stream << "#{@context_grammar_name} State #{@number}"
         stream << " (#{@close_duration})" if @close_duration.set?
         stream.end_line
         
         stream.indent do
            # stream.puts "Declared discards : #{declared_discards().collect{|s| s.description}.sort.join(", ")}"
            # stream.puts "Effective discards: #{effective_discards().collect{|s| s.description}.sort.join(", ")}"
            
            rows = []
            if context_free? then
               stream.puts "Context states are irrelevant to this State"
            else
               stream.puts "Context states: #{@context_states.keys.sort.join(", ")}"
            end
         
            #
            # We'd like our Item descriptors to be output in nice columns, so we will bypass the Item.display() routine.
      
            @items.each do |item|
               prefix_signatures = item.prefix.collect{|symbol| symbol.full_description}
               rest_signatures   = item.rest.collect{|symbol| symbol.full_description}
               rows << row = [ item.start_item ? "*" : (item.determinant_item ? "•" : " "), item.priority.to_s, item.production.name.description, prefix_signatures.join(" ") + " . " + rest_signatures.join(" ") ]
         
               case stream[:state_context]
                  when nil
                     tail = item.complete? ? (item.syntactic? ? item.determinants.join(" | ") : item.determinants.to_s) : nil
                  when :discards
                     tail = nil
                     tail = item.effective_discards.collect{|s| s.description}.join(", ") + " / " + item.declared_discards.collect{|s| s.description}.join(", ") if item.has_discards?
                  when :determinants
                     tail = item.complete? ? (item.syntactic? ? item.determinants.join(" | ") : item.determinants.to_s) : nil
                  when :determinants_plus
                     tail = item.complete? ? item.determinants.join(" | ") : item.sequences_after_mark(3).sequences.collect{|sequence| sequence.join(" ")}.join(" | ")
                  when :follow_contexts
                     tail = item.follow_contexts.collect{|context| context.to_s}.join(" | ")
                  when :raw_follow_contexts
                     tail = ""
                     item.instance_eval do
                        tail = item.follow_contexts.collect{|context| context.object_id.to_s}.join( " | " ) +
                               "Sources: " + item.follow_sources.collect{|source| source.object_id.to_s}.join( " | " )
                     end
                  else
                     bug( "what were you looking for? [#{show_context.to_s}]" )
               end
         
               row << tail
            end
         
            #
            # Calculate a width for each column.
         
            widths = [0, 0, 0, 0, 0]
            rows.each do |row|
               column = 0
               row.each do |datum|
                  unless datum.nil?
                     widths[column] = datum.length if widths[column] < datum.length
                  end
                  column += 1
               end
            end
                  
            #
            # Display the formatted items.
         
            format_string = "%s % #{widths[1]}s %-#{widths[2]}s => %-#{widths[3]}s"
            rows.each do |row|
               output = sprintf(format_string, row[0], row[1], row[2], row[3]).ljust(60)
               if row[4].nil? then
                  stream << output << "\n"
               else
                  stream << output << "   >>> Context >>> " << row[4] << "\n"
               end
            end
            
            #
            # Display transitions and reductions, but only if requested.
         
            if stream[:state_complete] then
            
               #
               # Display the transitions.
         
               unless @transitions.empty?
                  width = @transitions.keys.inject(0) {|current, symbol| length = symbol.to_s.length; current > length ? current : length }
                  @transitions.each do |symbol, state|
                     stream << sprintf("Transition %-#{width}s to %d", symbol, state.number) << "\n"
                  end
               end
                           
               #
               # Display the recovery options.
            
               @recovery_predicates.each do |symbol, predicate|
                  stream << "Recovery predicate for #{symbol}: #{predicate.class.name}" << "\n"
               end
            end
            
            
            #
            # Display actions, if requested.
            
            if stream[:state_complete] or stream[:state_actions] then
               if context_free? then
                  unless @symbolic_actions.empty?
                     stream << "Only relevant syntactic action: "
                     @symbolic_actions.each do |symbol_name, action|
                        stream.puts "#{action.to_s}"
                        break
                     end
                  end
                  
                  unless @literal_actions.empty?
                     stream << "Only relevant lexical action: "
                     @literal_actions.each do |symbol_name, action|
                        stream.puts "#{action.to_s}"
                        break
                     end
                  end
               else
                  width = 0
                  @symbolic_actions.each {|symbol_name, action| width = max(width, symbol_name.to_s.length) }
                  @literal_actions.each   {|symbol_name, action| width = max(width, symbol_name.to_s.length) }
                  
                  unless @symbolic_actions.empty?
                     stream.puts "Symbolic Actions:"
                     stream.indent do
                        (@symbolic_actions.keys.compact.sort + (@symbolic_actions.member?(nil) ? [nil] : [])).each do |symbol_name|
                           action = @symbolic_actions[symbol_name]
                           stream << "#{symbol_name.to_s.ljust(width)}: "
                           stream.indent(" " * (width + 2)) do 
                              stream.puts action.to_s
                           end
                        end
                     end
                  end
                  
                  unless (@literal_actions.nil? or @literal_actions.empty?)
                     stream.puts "Literal Actions:"
                     stream.indent do
                        @literal_actions.each do |character_range, action|
                           stream << "#{character_range.to_s.ljust(width)}: "
                           stream.indent(" " * (width + 2)) do 
                              stream.puts action.to_s
                           end
                        end
                     end
                  end
               end
                  
               unless @fallback_lexical_action.nil?
                  stream.puts "Fallback Lexical Action:"
                  stream.indent do
                     stream.puts @fallback_lexical_action.to_s
                  end
               end
            end
         end
      end





    #---------------------------------------------------------------------------------------------------------------------
    # Recovery planning
    #---------------------------------------------------------------------------------------------------------------------
    
    protected
      
      #
      # generate_recovery_plan()
      #  - generates a recovery predicate for the specified symbol_name

      def generate_recovery_plan( recovery_data )

         #
         # Pass 1: figure out which of our Items should be considered further.
         #
         # If the we have several ways to get to the same place, we want to consider only taking
         # one of the paths.  For instance, we wouldn't want to try both of these Items:
         #
         #   e => e . + e
         #   e => e . - e
         #
         # What would be the point?  If the + gets us somewhere, the - will get us to the same place.
         # Similarly, if the + gets us nowhere, the - won't either.  That said, if we had these Items:
         #
         #   e => e . + e
         #   e => e . * e
         #   e => e . * e + ( id )
         #
         # Now we have a problem.  * is worth trying even if + fails, because it leads to more than
         # one place.  In this case, we want to eliminate +, not *, as it can't get us anywhere * can't.  
         # That said, there may be cases where both forms diverge, in which case, both must stay in.

         recoverable_items = items.select do |item|
            item.leader.nil? || item.leader.refers_to_token? || (item.leader.refers_to_group? && !item.leader.token_names(@master_plan).empty?)
         end

         #
         # Start by grouping the shiftable items (this technique does nothing for reduce) by:
         #    product symbol, length, leader index, and item form (less the leader)

         items_by_form = {}
         recoverable_items.each do |item|
            unless item.complete?
               production = item.production
               prefix     = item.prefix.collect{|symbol| symbol.signature}.join(":")
               suffix     = item.rest.slice(1..-1).collect{|symbol| symbol.signature}.join(":")
               key = "#{production.signature}|#{production.length}|#{item.at}|#{prefix}::#{suffix}"

               items_by_form[key] = [] unless items_by_form.member?(key)
               items_by_form[key] << item
            end
         end

         #
         # Next, figure out the set of potential leader tokens for each key.  We don't care about
         # the key, any more -- it was used only to group together items that are identical with
         # the exception of the leader symbol.  Now we just want to go through each set and make
         # a list of those leader symbols for each.  Note we have to take care to pull token types 
         # out of group leaders.
         #
         # For the examples above, we'll have:
         #  [0]: + - *     
         #  [1]  *

         leader_options = []
         items_by_form.each do |key, items|
            leader_options << items.collect{|item| item.leader.token_names(@master_plan) }.flatten.uniq
         end

         # 
         # Next, we'll build a cross-product of the rows of leader_options.  Each leader_options
         # row contains "peer" symbols -- all possible symbols that will advance us along an otherwise-
         # identical set of productions.  By taking a cross-product, we figure out the potential 
         # combination of symbols needed to cover *all* such otherwise-identical-sets at least once.  
         #
         # Continuing our example, we'll have:
         #  [0]: + *
         #  [1]: - *
         #  [2]: * *
         #
         # We are interested in the minimum *set* of symbols needed to cover our productions.  In order 
         # to find this, we convert the cross-product rows to sets (with uniq!), then figure out which of 
         # these sets is the shortest.  If there is a tie, we arbitrarily pick one -- we only need
         # to cover all of the routes, not cover all possible input streams (fortunately).
         #
         # Again with the example:
         #  [0]: + *
         #  [1]: - *
         #  [2]: * 
         #
         # And row [2] is the winner.

         recoverable_shift_symbol_names = []
         unless leader_options.empty?
            matrix = leader_options[0].collect{|e| [e]}
            1.upto(leader_options.length-1) do |index|
               old_matrix = matrix
               matrix     = []

               leader_options[index].each do |element|
                  old_matrix.each do |row|
                     matrix << row + [element]
                  end
               end
            end

            count = matrix.inject(1000000000){ |current, row| row.uniq!; min(current, row.length) }

            matrix.each do |row|
               if row.length == count then
                  recoverable_shift_symbol_names = row
                  break
               end
            end
         end


         #
         # Phase 2: Given the list of acceptable shift recoveries, go through and generate recovery
         # options for both shift and reduce actions.

         recovery_data.each do |symbol_name, recoverable_items|
            predicate = nil
            recoverable_items.each do |item|
               predicate = Predicates::TryIt.new( item.generate_error_recoveries? )

               #
               # For REDUCE operations, we use the lookahead token only if a (run-time) context State
               # can SHIFT the token.

               if item.complete? then 
                  predicate = Predicates::CheckContext.new()

               #
               # For SHIFT operations, exclude anything not on our recoverable_shift_symbols list.

               elsif !recoverable_shift_symbol_names.member?(symbol_name) then
                  predicate = nil 

               #
               # If we are here, it's a SHIFT and we will be choosing predicates.

               else
                  @used_to_states[@transitions[symbol_name].number] = true

                  #
                  # If this is not a primary form, we do not insert tokens.

                  if item.production.generate_error_recoveries? then

                     #
                     # Forms that begin and end with a terminal are special.  We can consider them "matched" pairs.
                     #
                     #   e => . ( e )      ==> insert ( only if ) is the error
                     #   e => ( . e )      ==> not applicable (leader is a non-terminal)
                     #   e => ( e . )      ==> TryIt
                     #   e => ( e ) .      ==> REDUCE (already handled)

                     if item.at == 0 and item.production.symbols.length == 3 and item.production.symbols[0].refers_to_token? and item.production.symbols[-1].refers_to_token? then
                        predicate = Predicates::CheckErrorType.new( item.production.symbols[-1] )

                     #
                     # Prefix and postfix forms that result in the same type as one of their terms are a dead-end.
                     #   e => . - e        ==> bad, bad idea
                     #   e => - . e        ==> not applicable (leader is a non-terminal)
                     #   e => - e .        ==> REDUCE (already handled)
                     #
                     #   e => . e ++       ==> not applicable (leader is a non-terminal)
                     #   e => e . ++       ==> bad, bad idea
                     #   e => e ++ .       ==> REDUCE (already handled)

                     elsif item.production.symbols.length == 2 and item.leader.refers_to_token? and item.production.symbols[0].refers_to_token? ^ item.production.symbols[1].refers_to_token? and item.production.symbols[(item.at - 1).abs].signature == item.production.signature then
                        predicate = nil

                     end
                  end
               end

               break unless predicate.is_a?(Predicates::TryIt)
            end

            @recovery_predicates[symbol_name] = predicate unless predicate.nil? 
         end
      end



      


    #---------------------------------------------------------------------------------------------------------------------
    # Internal construction routines
    #---------------------------------------------------------------------------------------------------------------------
    
    protected


      #
      # add_item()
      #  - adds an Item to this production
      #  - has no effect if an Item with the same signature is already in the State
      
      def add_item( item )
         if @item_index.member?(item.signature) then
            @item_index[item.signature].add_follow_contexts_from( item )
         else
            @item_index[item.signature] = item
            @items << item
            @queue << item

            unless @closed
               @start_items << item
               item.start_item = true
               @context_free = false unless (item.complete? and item.syntactic?)
            end
         end
      end
      
      
      #
      # item_present?()
      #  - returns true if the Item is already in the State

      def item_present?( item )
         return @item_index.member?(item.signature)
      end
      
      
      #
      # enumerate_transitions()
      #  - calls your block once for every potential transition from this State
      #  - passes in the transition Symbol and the shifted Items it results in
      #  - constraint can be nil (for everything), :lexical, or :syntactic
      
      def enumerate_transitions( constraint = nil )
         assert( @closed, "you must call close() on State #{@number} before enumerating the transitions" )
         
         #
         # Continuing the discussion from close(), we must now compute the set of transitions from this State to other
         # States.  We will produce one transition for each leader Symbol, and produce a set of shifted Items representing
         # all transitions that can occur from our current state.  Each shift Items maintains it follow context connections,
         # which is how the overall follow context graph is built.
         #
         # Right.  One example, coming up.  ;-)
         #
         # Given our closed State (we'll dispense with lookahead concerns, for now):
         #    E => ( . E )    
         #    E => . V        
         #    E => . num      
         #    E => . ( E )    
         #    E => . E * E    
         #    E => . E / E    
         #    E => . E + E    
         #    E => . E - E    
         #    V => . id       
         #
         # Our leaders are: E V num ( id
         #
         # Therefore our potential output Item sets are:
         #    E => ( E . )
         #      => E . * E    
         #      => E . / E    
         #      => E . + E    
         #      => E . - E    
         #    E => V .        
         #    E => num .      
         #    E => ( . E )    
         #    V => id .       
         #
         # Note, finally, that there are no transitions for complete Items.  Such Items indicate reductions, not shifts.
         #
         

         #
         # First, sort the Items by leader symbol.  

         enumeration   = Util::OrderedHash.new()
         character_map = CharacterMap.new()
         source_items  = {}
         
         @items.each do |item|
            next if item.complete?
            
            item.leaders().each do |leader|
               next if ((constraint == :syntactic and leader.lexical?) or (constraint == :lexical and leader.syntactic?))
               
               shifted_item = item.shift
               source_items[shifted_item.signature] = item
               
               if leader.refers_to_character? then
                  character_map.merge_data( shifted_item, leader )
               else
                  enumeration[leader.name] = [] unless enumeration.member?(leader.name)
                  enumeration[leader.name] << shifted_item
               end
            end
         end
         
         #
         # Yield for each in turn.
         
         enumeration.each do |leader_name, items|
            yield( leader_name, items ) unless @transitions.member?(leader_name)
         end
         
         character_map.each do |range, items|
            yield( range, items ) unless @transitions.member?(range)
         end
      end



      #
      # DiscardPlan
      #  - used by compile_actions() to plan the retransitioning due to discards
      
      class DiscardPlan
         attr_reader :reduce_items, :shift_items, :discard_items
         
         def self.instance( hash, symbol_name )
            hash[symbol_name] = new(symbol_name) unless hash.member?(symbol_name)
            return hash[symbol_name]
         end         
         
         def initialize( symbol_name )
            @symbol_name     = symbol_name
            @reduce_items    = []
            @shift_items     = []
            @discard_items   = []
         end

         def compile( state, state_table )
            if @action.nil? then
               warn_nyi( "commit point support for discard actions" )
               warn_nyi( "what should last_is_longest be for discard actions?" )
               
               actions = []
               attempt_span = 0
               last_is_longest = nil
               
               @reduce_items.each do |item|
                  actions << Actions::Reduce.new( item.production )
                  attempt_span = max(attempt_span, item.length)
               end

               unless @shift_items.empty?
                  actions << Actions::Shift.new( @symbol_name, state.transitions[symbol_name], @shift_items.collect{|item| item.production}.uniq, false )
                  attempt_span = @shift_items.inject(attempt_span){|span, item| max(span, item.length) }
               end
               
               unless @discard_items.empty?
                  
                  #
                  # First, create a new state for the discard items.
                  
                  transfers = @discard_items.collect{|item| item.transfer() }
                  discard_state = state_table.create_state( transfers, state )
                  transfer_transferable_transitions( state, discard_state, state_table, transfers )
                  
                  puts "Discard state: #{discard_state.number}" 

                  #
                  # And generate the actions.
                  
                  actions << Actions::Discard.new( @symbol_name, discard_state )
                  attempt_span = @discard_items.inject(attempt_span){|span, item| max(span, item.length) }
               end

               if actions.length == 1 then
                  @action = actions[0]
               else
                  @action = Actions::Attempt.new( actions, attempt_span, last_is_longest )
               end
            end
            
            return @action
         end
         
         
         def transfer_transferable_transitions( old_state, discard_state, state_table, transfers ) 
            items_by_leader = {}
            transfers.each do |item|
               item.leaders.each do |leader|
                  next unless leader.syntactic?
                  items_by_leader.accumulate( leader, item )
               end
            end
            
            items_by_leader.each do |leader, items|
               existing_target = old_state.transitions[leader.name]
               if existing_target.start_items.length == items.length then
                  discard_state.add_transition( leader.name, existing_target )
               end
            end
         end
         
         
         
      end
      
      
      
   end # State
   




end  # module Plan 
end  # module RCC




