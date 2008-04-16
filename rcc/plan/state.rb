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
         
         start_productions = ProductionSet.new()
         start_productions << Production.start_production( start_rule_name )
         
         state.add_productions( start_productions )
         
         return state
      end
      



    #---------------------------------------------------------------------------------------------------------------------
    # Initialization and construction
    #---------------------------------------------------------------------------------------------------------------------

      attr_reader   :master_plan
      attr_reader   :signature
      attr_reader   :number
      attr_reader   :items
      attr_reader   :transitions
      attr_reader   :reductions
      attr_reader   :lookahead
      attr_reader   :actions
      attr_reader   :explanations
      attr_reader   :lookahead_explanations
      attr_reader   :lexer_plan
      attr_reader   :recovery_predicates
      attr_accessor :context_grammar_name
      
      def initialize( master_plan, state_number = 0, start_items = [], context_state = nil  )
         @master_plan            = master_plan        # I think this is self-explanatory ;-)
         @number                 = state_number       # The number of this State within the overall ParserPlan
         @items                  = []                 # All Items in this State
         @start_items            = []                 # The Items that started this State (ie. weren't added by close())
         @closed                 = false              # A flag indicating that close() has been called
         @signature              = nil                # A representation of this State that will be common to all mergable States
         @transitions            = {}                 # Symbol.name => State
         @reductions             = []                 # An array of complete? Items
         @queue                  = []                 # A queue of unclosed Items in this State
         @lookahead              = []                 # The names of the Terminals we expect on lookahead
         @actions                = nil                # Symbol.name => Action
         @explanations           = nil                # A set of Explanations for the Actions, if requested during creation
         @lookahead_explanations = nil                # An InitialOptions Explanation, if requested
         @lexer_plan             = nil                # A LexerPlan that gives our lookahead requirements precedence
         @context_grammar_name   = context_state.nil? ? nil : context_state.context_grammar_name

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
      # provide_context()
      #  - wraps this State's context around your block
      
      def provide_context()
         Scanner::Artifacts::Name.in_grammar(@context_grammar_name) do
            yield( self )
         end
      end

      
      #
      # add_productions( )
      #  - adds all Productions in a ProductionSet to this state, as 0 mark Items
      
      def add_productions( production_set, context_items = nil )
         production_set.productions.each do |production|
            add_item( Item.new(production, 0, context_items) )
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
      
      def close()
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
            # We only have (further) work to do if the Item has a Production leader.  Our add_productions()
            # subsystem deals with adding/merging Items, as appropriate.
                        
            if item.complete? then
               @reductions << item
               
               if item.production.postfilter then
                  add_productions( @master_plan.production_sets[item.production.postfilter.name], item ) 
               end
            else
               if item.leader.refers_to_production? or item.leader.refers_to_group? then
                  if @master_plan.production_sets.member?(item.leader.name) then
                     add_productions( @master_plan.production_sets[item.leader.name], item )
                  elsif item.leader.refers_to_production? then
                     nyi "error handling for missing reference name [#{item.leader.name}]" 
                  end
               end
               
               #
               # Handle the prefilter, if present.  The prefilter is a Production-referring Symbol that
               # is used to read and discard and ignored tokens that precede the item.leader.
               
               prefilter = item.leader.prefilter
               if prefilter then
                  add_productions( @master_plan.production_sets[prefilter.name], item )
               end
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
      
      def enumerate_transitions( exclude_discarders = true )
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
         # A NEW WRINKLE: every Symbol may have a prefilter Symbol, which may or may not be present before the actual
         # Symbol.  The prefilter rule will generally have a Discard resolution, and we generally use this feature to
         # strip out ignorable tokens (like whitespace and comments) during parsing.  However, we don't generally 
         # enumerate these prefilters here, as a Discarder doesn't leave a symbol on the stack, and so it will never
         # be shifted.  If you really want them included, you can set exclude_discarders to false.
         
         #
         # First up, sort the Items by leader symbol.
         
         enumeration = Util::OrderedHash.new()
         @items.each do |item|
            filter = nil
            
            if item.complete? then
               filter = item.production.postfilter
            else
               symbol = item.leader
               
               if symbol.refers_to_group? then
                  @master_plan.group_members[symbol.name].each do |member|
                     enumeration[member.name] = [] unless enumeration.member?(member.name)
                     enumeration[member.name] << item.shift
                  end
               else
                  enumeration[symbol.name] = [] unless enumeration.member?(symbol.name)
                  enumeration[symbol.name] << item.shift
               end
               
               filter = symbol.prefilter
            end

            #
            # If the filter is a Discarder, it will never be shifted.  We include it only
            # if isn't a Discarder.
            
            if filter then
               if filter.refers_to_discarder? then
                  unless exclude_discarders
                     enumeration[filter.name] = [] unless enumeration.member?(filter.name)
                     enumeration[filter.name] << item
                  end
               else
                  nyi( "what is the result of shifting a non-Discarder prefilter?" )
               end
            end
         end
         
         #
         # Yield for each in turn.
         
         enumeration.each do |leader_name, items|
            yield( leader_name, items )
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
      
      def compile_actions( use_backtracking = false, estream = nil )
         explain       = @master_plan.produce_explanations
         @explanations = (explain ? {} : nil)
         @actions      = {}
         
         
         #
         # Merge the potential shift commit actions down to a single action for any shift (including
         # production shifts).  If there is only one, then we do it.  If there are multiples and they 
         # are not all the same, we do nothing.
         
         shift_commits_by_leader = {}
         @items.each do |item|
            next if item.complete?
            next if item.production.discard?
            
            shift_commits_by_leader[item.leader.name] = [] unless shift_commits_by_leader.member?(item.leader.name)
            shift_commits_by_leader[item.leader.name] << item.leader.commit_point
         end
         
         shift_commits_by_leader.each do |symbol_name, shift_commits|
            shift_commit = shift_commits[0]
            shift_commit.each do |type|
               if type != shift_commit then
                  shift_commit = nil
                  break
               end
            end
            
            shift_commits_by_leader[symbol_name] = shift_commit
         end
            

         #
         # Next, sort into lists of options.  We'll immediately create and store actions
         # for Gotos, as they are very simple to do, and we don't want the complicating later
         # work.         
         
         ignore  = []
         options = {}
         @items.each do |item|  
            
            #
            # For complete Discarders, we don't need to bother checking any lookahead.  Discarders
            # are always "floaters", so there is no point calculating determinants (we use >true< as
            # the wildcard lookahead type).
            
            if item.complete? and item.production.discard? then
               options[Scanner::Artifacts::Name.any_type] = [] unless options.member?(Scanner::Artifacts::Name.any_type)
               options[Scanner::Artifacts::Name.any_type] << item
               
            #
            # If the Item leader is a Production, generate Goto actions.
            
            elsif !item.complete? and item.leader.refers_to_production? then
               @actions[item.leader.name] = Actions::Goto.new( @transitions[item.leader.name], shift_commits_by_leader[item.leader.name] )

               
            #
            # If the Item leader is a Group, we've got work to do.  For Production members, we 
            # produce a Goto action.  For Token members, we register the token as a determinant.
            
            elsif !item.complete? and item.leader.refers_to_group? then
               @master_plan.group_members[item.leader.name].each do |member|
                  if member.refers_to_production? then
                     @actions[member.name] = Actions::Goto.new( @transitions[member.name], shift_commits_by_leader[item.leader.name] ) unless @actions.member?(member.name)
                  else
                     options[member.name] = [] unless options.member?(member.name)
                     options[member.name] << item
                   
                     ignore << member.name if item.production.discard?
                  end
               end
               
            #
            # Otherwise, generate lists of options, grouped by la(1) symbol.
            
            else
               determinants = nil
               duration = Time.measure do
                  determinants = item.determinants( 1 )
               end

               $stderr.puts "Determinants calculation for state #{@number} item [#{item.signature}] duration: #{duration}s" if $stderr['show_statistics'] and duration > 0.1

               determinants.each do |determinant|
                  options[determinant.name] = [] unless options.member?(determinant.name)
                  options[determinant.name] << item
                  
                  ignore << determinant.name if item.production.discard?
               end
            end
         end
         
         @lookahead = options.keys - ignore
         
         #
         # Select an action for each lookahead terminal.
         
         @lookahead_explanations = Explanations::InitialOptions.new(options) if explain

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
                  if lhs.production.priority == rhs.production.priority then
                     lhs.complete? ^ rhs.complete? ? (lhs.complete? ? -1 : 1) : 0
                  else
                     lhs.production.priority <=> rhs.production.priority
                  end
               end

               reduce_priority = 10000000000
               sorted.each do |item|
                  if item.production.priority > reduce_priority then    # priority 1 is higher than priority 2
                     discarded << item
                  elsif item.complete? then
                     in_play << item
                     reduce_priority = item.production.priority
                  else
                     in_play << item
                  end
               end
               
               explanations << Explanations::ItemsDoNotMeetThreshold.new( discarded ) if explain and !discarded.empty?
               
               #
               # At this point, in_play contains 0 or more high priority shifts followed by a set
               # of 0 or more shifts and reduces at the same priority.  We have to look at that 
               # second set (if present) and apply associativity.
               
               keep_set  = []
               assoc_set = []
               
               in_play.each do |item|
                  if item.production.priority < reduce_priority then    # priority 1 is higher than priority 2
                     keep_set << item
                  else
                     assoc_set << item
                  end
               end
               
               unless assoc_set.empty?
                  assoc_shifts     = assoc_set.select{ |item| !item.complete? }
                  assoc_reductions = assoc_set.select{ |item| item.complete?  }
                  
                  assoc_shifts.each do |shift|
                     assoc_reductions.each do |reduction|
                        case reduction.production.associativity
                           when :none
                              warn_nyi( "nonassociativity" )
                              # eliminated_reductions << reduction
                              # error_actions         << Actions::NonAssociativityViolation.new( shift, reduction )
                              # explanations          << Explanations::NonAssociativityViolation.new( shift, reduction ) if explain
                           when :left
                              assoc_set.delete_if{ |item| item.object_id == shift.object_id }
                              explanations << Explanations::LeftAssocReduceEliminatesShift.new( reduction, shift ) if explain
                           else
                              assoc_set.delete_if{ |item| item.object_id == reduction.object_id }
                              explanations << Explanations::RightAssocReduceEliminated.new( shift, reduction ) if explain
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
               break if item.complete?
               valid_productions << item.production
            end
            
            #
            # Next, convert the in_play items to actions.
            
            shift_created = false
            actions       = []
            in_play.each do |item|
               if item.complete? then
                  production = item.production
                  actions << (production.discard? ? Actions::Discard.new(production) : Actions::Reduce.new(production))
               elsif symbol_name.eof? then
                  actions << Actions::Accept.new( item.production )
               elsif !shift_created then
                  actions << Actions::Shift.new( symbol_name, @transitions[symbol_name], valid_productions, shift_commits_by_leader[item.leader.name] )
                  shift_created = true
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
                  @actions[symbol_name] = actions[0]
               else
                  explanations << Explanations::BacktrackingActivated.new( actions ) if explain
                  @actions[symbol_name] = Actions::Attempt.new( actions )
            end
            
            #
            # Finish up.
            
            @explanations[symbol_name] = explanations if explain
            recovery_data[symbol_name] = in_play
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
     
         recoverable_items = @items.select do |item|
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
      
      def compile_customized_lexer_plan( base_plan, estream = nil )
         @lexer_plan = base_plan.prioritize( @lookahead )
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
         stream.puts "#{@context_grammar_name} State #{@number}"
         stream.indent do
            
            rows = []
            if @actions.exists? and @actions.length == 1 and @actions.member?(Name.any_type) then
               stream.puts "Context states are irrelevant to this State"
            else
               
               stream.puts "Context states: #{@context_states.keys.sort.join(", ")}"
         
               #
               # We'd like our Item descriptors to be output in nice columns, so we will bypass the Item.display() routine.
         
               @items.each do |item|
                  prefix_signatures = item.prefix.collect{|symbol| symbol.name.description}
                  rest_signatures   = item.rest.collect{|symbol| symbol.name.description}
                  rows << row = [ item.start_item ? "*" : " ", item.production.name.description, prefix_signatures.join(" ") + " . " + rest_signatures.join(" ") ]
            
                  case stream[:state_context]
                     when nil, :determinants
                        tail = item.complete? ? item.determinants.join(" | ") : nil
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
         
            format_string = "%s %-#{widths[1]}s => %-#{widths[2]}s"
            rows.each do |row|
               output = sprintf(format_string, row[0], row[1], row[2]).ljust(60)
               if row[3].nil? then
                  stream << output << "\n"
               else
                  stream << output << "   >>> Context >>> " << row[3] << "\n"
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
               # Display the reductions.
         
               unless @reductions.empty?
                  @reductions.each do |item|
                     stream << "Reduce rule #{item.production.name} => #{item.production.symbols.join(" ")}" 
                     stream << " (*)" if item.object_id == @chosen_reduction.object_id
                     stream << "\n"
                  end
               end
            
               #
               # Display the recovery options.
            
               @recovery_predicates.each do |symbol, predicate|
                  stream << "Recovery predicate for #{symbol}: #{predicate.class.name}" << "\n"
               end
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

      
      
   end # State
   




end  # module Plan 
end  # module RCC
