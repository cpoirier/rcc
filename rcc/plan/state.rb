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
require "#{$RCCLIB}/model/rule.rb"
require "#{$RCCLIB}/model/form.rb"
require "#{$RCCLIB}/plan/item.rb"
require "#{$RCCLIB}/plan/actions/action.rb"
require "#{$RCCLIB}/plan/explanations/explanation.rb"
require "#{$RCCLIB}/plan/predicates/predicate.rb"
require "#{$RCCLIB}/util/ordered_hash.rb"

module RCC
module Plan

 
 #============================================================================================================================
 # class State
 #  - a single state in the parser

   class State
      
      #
      # ::signature()
      #  - returns the signature for a set of start Items
      
      def self.signature( start_items )
         return start_items.collect{|item| item.signature}.sort.join("\n")
      end
      
      
      def self.start_state( start_rule_name, production_sets )
         state = new( 0 )
         state.add_productions( ProductionSet.start_set(start_rule_name), nil, production_sets )
         
         return state
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and construction
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader :signature
      attr_reader :number
      attr_reader :items
      attr_reader :transitions
      attr_reader :reductions
      attr_reader :lookahead
      attr_reader :actions
      attr_reader :explanations
      attr_reader :lookahead_explanations
      attr_reader :lexer_plan
      attr_reader :recovery_predicates
      
      def initialize( state_number, start_items = [], context_state = nil  )
         @number       = state_number    # The number of this State within the overall ParserPlan
         @items        = []              # All Items in this State
         @start_items  = []              # The Items that started this State (ie. weren't added by close())
         @closed       = false           # A flag indicating that close() has been called
         @signature    = nil             # A representation of this State that will be common to all mergable States
         @transitions  = {}              # Symbol.name => State
         @reductions   = []              # An array of complete? Items
         @queue        = []              # A queue of unclosed Items in this State
         @lookahead    = []              # The names of the Terminals we expect on lookahead
         @actions      = nil             # Symbol.name => Action
         @explanations = nil             # A set of Explanations for the Actions, if requested during creation
         @lookahead_explanations = nil   # An InitialOptions Explanation, if requested
         @lexer_plan   = nil             # A LexerPlan that gives our lookahead requirements precedence

         @item_index   = {}              # An index used to avoid duplication of Items within the State
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
      
      
      #
      # add_productions( )
      #  - adds all Productions in a ProductionSet to this state, as 0 mark Items
      
      def add_productions( production_set, context_items = nil, production_sets = nil )
         production_set.productions.each do |production|
            add_item( Item.new(production, 0, context_items, production_sets) )
         end
      end
      
      #
      # add_contexts()
      #  - adds follow contexts to our start phrases, given a set of start Items that would otherwise
      #    be used to make an identical State
      
      def add_contexts( shifted_items, context_state )
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
      
      def close( production_sets )
         @closed    = true
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
         
         until @queue.empty? 
            item = @queue.shift
            
            #
            # We only have (further) work to do if the Item has a non-terminal leader.  Our add_productions()
            # subsystem deals with adding/merging Items, as appropriate.
            
            if item.complete? then
               @reductions << item
            elsif !item.leader.terminal?
               set_name_to_add = item.leader.name
               nyi "error handling for missing reference name [#{set_name_to_add}]" unless production_sets.member?(set_name_to_add)
               add_productions( production_sets[set_name_to_add], item, production_sets )
            end
         end

         #
         # Whew!  That was a lot of talking for such a very little bit of code . . . .
         # Anyway, before leaving, we can free up the Item index, as we are now closed to new Items.
         
         @item_index = nil
         
      end


      #
      # enumerate_transitions()
      #  - calls your block once for every potential transition from this State
      #  - passes in the transition Symbol and the shifted Items it results in
      
      def enumerate_transitions()
         assert( @closed, "you must close() the State before enumerating the transitions" )
         
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
         # First up, sort the Items by leader symbol.
         
         enumeration = Util::OrderedHash.new()
         @items.each do |item|
            unless item.complete?
               symbol = item.leader()
               if enumeration.member?(symbol.name) then
                  enumeration[symbol.name] << item.shift
               else
                  enumeration[symbol.name] = [item.shift]
               end
            end
         end
         
         #
         # Yield for each in turn.
         
         enumeration.each do |leader, items|
            yield( leader, items )
         end
      end
      
      
      #
      # add_transition()
      #  - registers a transition from this to another for the specified Symbol name
      
      def add_transition( symbol_name, transition_state )
         @transitions[symbol_name] = transition_state
      end
      
            
      #
      # compile_actions()
      #  - resolves conflicts and generates a list of actions for this State
      #  - each action indicates what to do when a specific terminal is on lookahead
      
      def compile_actions( production_sets, precedence_table, k_limit = 1, use_backtracking = false, explain = false )
         
         @explanations = (explain ? {} : nil)
         @actions      = {}
         
         #
         # First, sort into lists of options.  If the Item leader is a non-terminal, generate Goto actions immediately 
         # (they're a no-brainer).  Otherwise, generate lists of options: Items grouped by la(1) terminal name.
         
         options = {}
         @items.each do |item|
            if !item.complete? and item.leader.non_terminal? then
               @actions[item.leader.name] = Actions::Goto.new( @transitions[item.leader.name] )
            else
               determinants = nil
               duration = Time.measure do
                  determinants = item.determinants( 1, production_sets )
               end
               
               STDERR.puts "Determinants calculation for state #{@number} item [#{item.signature}] duration: #{duration}s" if $show_statistics and duration > 0.1

               determinants.each do |determinant|
                  options[determinant.name] = [] unless options.member?(determinant.name)
                  options[determinant.name] << item
               end
            end
         end
         
         @lookahead = options.keys

         
         #
         # Select an action for each lookahead terminal.
         
         @lookahead_explanations = Explanations::InitialOptions.new(options) if explain

         recovery_data = {}
         options.each do |symbol_name, items|

            explanations          = []
            all_accepts           = []
            all_reductions        = []
            eliminated_reductions = []
            all_shifts            = []
            eliminated_shifts     = []
            error_actions         = []


            #
            # If there is only one option for an la(1) Symbol, life is good.  

            if items.length == 1 then
               item = items[0]
               explanations << Explanations::OnlyOneChoice.new( item )
               
               if item.complete? then
                  all_reductions << item
               else
                  all_shifts     << item
               end
               
            #
            # Otherwise, either we must increase the lookahead length, request backtracking, or do something arbitrary.  
            # Associativity and precedence are the best "arbitrary" things to do.
            
            else
               
               #
               # We'll use associativity-based conflict resolution a lot.  We'll make it a Proc to save duplicating 
               # the code.  The decision is always on the associativity of the reduction Production:
               #   left-associativity  -- perform the reduce
               #   right-associativity -- perform the shift
               #   no associativity    -- invalidate both ops, create an Error Action

               process_associativity = lambda() do |shift, reduction|
                  case reduction.production.associativity
                     when "none"
                        eliminated_reductions << reduction
                        error_actions         << Actions::NonAssociativityViolation.new( shift, reduction )
                        explanations          << Explanations::NonAssociativityViolation.new( shift, reduction ) if explain
                     when "left"
                        eliminated_shifts     << shift
                        explanations          << Explanations::ReduceTrumpsShift.new( reduction, shift, true ) if explain
                     else
                        eliminated_reductions << reduction
                        explanations          << Explanations::ShiftTrumpsReduce.new( shift, reduction, true ) if explain
                  end
               end


               #
               # Start by splitting the Items into reductions and shifts.
               
               items.each do |item|
                  if item.complete? then
                     all_reductions << item
                  else
                     all_shifts     << item
                  end
               end

               
               #
               # Sort the reductions by priority: lower Production numbers first.
               
               all_reductions.sort!{|lhs, rhs| lhs.production.number <=> rhs.production.number }
               explanations << Explanations::ReductionsSorted.new( all_reductions ) if explain and all_reductions.length > 1

               
               #
               # Arbitrate between shift/reduce conflicts by precedence and associativity, where available.
               
               all_shifts.each do |shift|
                  reductions.each do |reduction|
                     shift_tier     = precedence_table[shift.production.number]
                     reduction_tier = precedence_table[reduction.production.number]
                     
                     #
                     # If both items hold the same Production, we'll let associativity decide.  
                     
                     if shift.production.number == reduction.production.number then
                        process_associativity.call( shift, reduction )
                        
                     #
                     # Otherwise, if both items have precedence setings, we'll let it or associativity decide.
                     
                     elsif !shift_tier.nil? and !reduction_tier.nil? then

                        #
                        # Lower tier numbers indicate higher precedence.  To make the math more intuitive,
                        # we'll negate them.
                     
                        shift_precedence     = shift_tier * -1
                        reduction_precedence = reduction_tier * -1
                     
                        #
                        # If the shift precedence is higher, we shift.  The reduction is eliminated.
                     
                        if shift_precedence > reduction_precedence then
                           eliminated_reductions << reduction
                           explanations          << Explanations::ShiftTrumpsReduce.new( shift, reduction ) if explain
                        
                        #
                        # If the reduction precedence is higher, we reduce.  The shift is eliminated.
                        # Note that the lists are already arranged appropriately for this.
                        
                        elsif shift_precedence < reduction_precedence then
                           eliminated_shifts << shift
                           explanations      << Explanations::ReduceTrumpsShift.new( reduction, shift ) if explain
                        
                        #
                        # Otherwise, we pick on associativity of the reduction.
                     
                        else 
                           process_associativity.call( shift, reduction )
                        end
                        
                     #
                     # Actually, if both items lack precedence, and are different forms of the same rule, we'll
                     # let associativity decide.  Seems reasonable.
                     
                     elsif shift_tier.nil? and reduction_tier.nil? and shift.production.rule_name == reduction.production.rule_name then
                        process_associativity.call( shift, reduction )
                     
                     end
                  end
               end
            end

            
            #
            # Produce actions for the set, in the following order: valid shifts, valid reductions, error actions.
            # If we end up with only one, we return it.  Otherwise, we we create an Attempt action to trigger 
            # backtracking support.  
            #
            # BUG: At some point, k>1 could eliminate some backtracking, and would be especially useful for 
            # reduce/reduce conflicts.
            
            actions               = []
            action_items          = []
            chosen_shift_actions  = []
            chosen_reduce_actions = []
            
            valid_shifts = (all_shifts - eliminated_shifts)
            unless valid_shifts.empty?
               
               #
               # We care only about the first shift (they all shift the same thing), but for backtracking,
               # we also care that, ultimately, we produce one of the valid productions.  
               
               valid_productions = valid_shifts.collect{|shift| shift.production}

               shift = valid_shifts[0]
               if symbol_name.nil? then
                  actions << Actions::Accept.new( shift.production )
                  action_items << shift
               else
                  shift_action = Actions::Shift.new( symbol_name, @transitions[symbol_name], valid_productions )
                  chosen_shift_actions << shift_action
                  actions              << shift_action
                  action_items         << shift
               end
            end
            
            (all_reductions - eliminated_reductions).each do |reduction|
               reduce_action = Actions::Reduce.new( reduction.production )
               chosen_reduce_actions << reduce_action
               actions               << reduce_action
               action_items          << reduction
            end
            
            actions.concat( error_actions )
            
            if actions.length == 0 then
               bug "what the hell does this mean?"
            elsif actions.length == 1 then
               @actions[symbol_name] = actions[0]
            else
               if use_backtracking then
                  @actions[symbol_name], additional_explanations = compile_backtracking_actions( chosen_shift_actions, chosen_reduce_actions, error_actions, explain )
                  explanations.concat( additional_explanations ) if explain
               else
                  explanations << Explanations::FavouriteChosen.new( actions ) if explain
                  @actions[symbol_name] = actions[0]
               end
            end
            
            assert( !@actions[symbol_name].nil?, "wtf?" )
            
            if explain then
               explanations << Explanations::SelectedAction.new( @actions[symbol_name] )
               @explanations[symbol_name] = explanations 
            end
            
            
            #
            # Finally, stash the recovery data so we can generate a recovery plan.
            
            recovery_data[symbol_name] = action_items
         end


         #
         # Generate a recovery plan for the state.
         
         generate_recovery_plan( recovery_data )
         
         
      end
      
      
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
         
         recoverable_items = @items.select{|item| (item.leader.nil? or item.leader.terminal?) }
         
         #
         # Start by grouping the shiftable items (this technique does nothing for reduce) by:
         #    product symbol, length, leader index, and item form (less the leader)
         
         items_by_form = {}
         recoverable_items.each do |item|
            unless item.complete?
               production = item.production
               prefix     = item.prefix.collect{|symbol| symbol.to_s}.join(":")
               suffix     = item.rest.slice(1..-1).collect{|symbol| symbol.to_s}.join(":")
               key = "#{production.rule_name}|#{production.length}|#{item.at}|#{prefix}::#{suffix}"
               
               items_by_form[key] = [] unless items_by_form.member?(key)
               items_by_form[key] << item
            end
         end
         
         #
         # Select the minimum number of items necessary to ensure at least one item is represented
         # from each form.  We'll take the cross-product of the groups and pick the first, shortest
         # combination.  
         
         leader_options = []
         items_by_form.each do |key, items|
            leader_options << items.collect{|item| item.leader}
         end

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
                  recoverable_shift_symbol_names = row.collect{ |symbol| symbol.name }
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
               predicate = Predicates::TryIt.new( item.minimal_phrasing? )
               
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
         
                  if item.production.minimal_phrasing? then
         
                     #
                     # Forms that begin and end with a terminal are special.  We can consider them "matched" pairs.
                     #
                     #   e => . ( e )      ==> insert ( only if ) is the error
                     #   e => ( . e )      ==> not applicable (leader is a non-terminal)
                     #   e => ( e . )      ==> TryIt
                     #   e => ( e ) .      ==> REDUCE (already handled)
         
                     if item.at == 0 and item.production.symbols.length == 3 and item.production.symbols[0].terminal? and item.production.symbols[-1].terminal? then
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
            
                     elsif item.production.symbols.length == 2 and item.leader.terminal? and item.production.symbols[0].terminal? ^ item.production.symbols[1].terminal? and item.production.symbols[(item.at - 1).abs].name == item.production.name then
                        predicate = nil
                        
                     end
                  end
               end
            
               break unless predicate.is_a?(Predicates::TryIt)
            end
         
            @recovery_predicates[symbol_name] = predicate unless predicate.nil? 
         end
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
      
      
      #
      # compile_customized_lexer_plan()
      #  - produces/returns a LexerPlan that prioritizes the lookahead for this State's actions
      
      def compile_customized_lexer_plan( base_plan )
         @lexer_plan = base_plan.prioritize( @lookahead )
      end
      
   



    #---------------------------------------------------------------------------------------------------------------------
    # Conversion and formatting
    #---------------------------------------------------------------------------------------------------------------------

      def to_s()
         return "State"
      end

      def display( stream )  # stream, indent = "", complete = true, show_context = :reduce_determinants )
         stream << indent << "State #{@number}\n"
         stream << indent << "   Context states: #{@context_states.keys.sort.join(", ")}\n"

         #
         # We'd like our Item descriptors to be output in nice columns, so we will bypass the Item.display() routine.
         
         rows = []
         @items.each do |item|
            rows << row = [ item.start_item ? "*" : " ", item.rule_name, item.prefix.join(" ") + " . " + item.rest.join(" ") ]
            
            case show_context
               when nil, :reduce_determinants
                  tail = item.complete? ? item.determinants.join(" | ") : nil
               when :all_determinants
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
         
         widths = [0, 0, 0, 0]
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
         
         format_string = "   %s %-#{widths[1]}s => %-#{widths[2]}s"
         rows.each do |row|
            output = sprintf(format_string, row[0], row[1], row[2]).ljust(60)
            if row[3].nil? then
               stream << indent << output << "\n"
            else
               stream << indent << output << "   >>> Context >>> " << row[3] << "\n"
            end
         end
         
         #
         # Display transitions and reductions, but only if requested.
         
         if complete then
            
            #
            # Display the transitions.
         
            unless @transitions.empty?
               width = @transitions.keys.inject(0) {|current, symbol| length = symbol.to_s.length; current > length ? current : length }
               @transitions.each do |symbol_name, state|
                  stream << indent << sprintf("   Transition %-#{width}s to %d", symbol_name, state.number) 
                  stream << "\n"
               end
            end
         
            #
            # Display the reductions.
         
            unless @reductions.empty?
               @reductions.each do |item|
                  stream << indent << "   Reduce rule #{item.production.name} => #{item.production.symbols.join(" ")}" 
                  stream << " (*)" if item.object_id == @chosen_reduction.object_id
                  stream << "\n"
               end
            end
            
            #
            # Display the recovery options.
            
            @recovery_predicates.each do |symbol, predicate|
               stream << indent << "   Recovery predicate for #{symbol}: #{predicate.class.name}" << "\n"
            end
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
      # compile_backtracking_actions()
      #  - helper for compile_actions that processing a set of actions into an Attempt plan
      #  - returns an Action and an array of Explanations
      
      def compile_backtracking_actions( shift_actions, reduce_actions, error_actions, explain )

         explanations = []
         
         #
         # We still solve reduce/reduce conflicts by taking the first declared rule.

         if reduce_actions.length > 1 then
            explanations << Explanations::FavouriteChosen.new( reduce_actions ) if explain
            reduce_actions = [reduce_actions[0]]
         end
         
         #
         # For shift/reduce conflicts, we try shift first, then reduce.
         
         actions = shift_actions + reduce_actions + error_actions

         if actions.length == 1 then
            return actions[0], explanations
         else
            explanations << Explanations::BacktrackingActivated.new( actions ) if explain
            return Actions::Attempt.new( shift_actions + reduce_actions + error_actions ), explanations
         end
      end
      
      
   end # State
   




end  # module Plan 
end  # module RCC
