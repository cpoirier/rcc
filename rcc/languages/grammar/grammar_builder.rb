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
require "#{$RCCLIB}/languages/grammar/grammar.rb"
require "#{$RCCLIB}/languages/grammar/naming_context.rb"
require "#{$RCCLIB}/util/sparse_range.rb"
require "#{$RCCLIB}/util/directed_acyclic_graph.rb"
require "#{$RCCLIB}/util/expression_forms/expression_form.rb"
require "#{$RCCLIB}/model/model.rb"


module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class GrammarBuilder
 #  - builds an RCC::Model::Grammar from an AST parsed from a grammar source file

   class GrammarBuilder
      
      Node                   = RCC::Scanner::Artifacts::Node
      Token                  = RCC::Scanner::Artifacts::Nodes::Token
      Name                   = RCC::Scanner::Artifacts::Name
      Group                  = RCC::Model::Elements::Group
      Rule                   = RCC::Model::Elements::Rule
      Pluralization          = RCC::Model::Elements::Pluralization
      StringDescriptor       = RCC::Model::Elements::StringDescriptor
      StringReference        = RCC::Model::Markers::StringReference
      RuleReference          = RCC::Model::Markers::RuleReference
      GroupReference         = RCC::Model::Markers::GroupReference
      PluralizationReference = RCC::Model::Markers::PluralizationReference
      LocalCommit         = RCC::Model::Markers::LocalCommit      
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize( grammar_spec, model_builder )
         assert( grammar_spec.type == "RCC.grammar_spec", "Um, perhaps you meant to pass a grammar_spec AST?" )
         
         @name                = grammar_spec.name.text
         @grammar_spec        = grammar_spec
         @model_builder       = model_builder
         
         @specifications      = Util::OrderedHash.new()       # name => spec, in declaration order
         @option_specs        = []
         @pluralization_specs = Util::OrderedHash.new()
         @reorder_specs       = []
         
         @string_defs         = Util::OrderedHash.new()       # name => ExpressionForm of SparseRange
         @group_defs          = Util::OrderedHash.new()       # name => Group
         @rule_defs           = Util::OrderedHash.new()       # name => Rule
         @naming_contexts     = Util::OrderedHash.new()       # name => naming context data
      end



      #
      # build_model()
      #  - builds the Model::Grammar from specs
      
      def build_model()

         #
         # Register the grammar specifications (only).  Only do this on the first call.
         
         if @specifications.empty? then
            register_specs( @grammar_spec.specifications ) 
            integrate_transformations( @grammar_spec.transformations.transformation_sets ) if @grammar_spec.slot_filled?("transformations")
         end
         

         #
         # Resolve string specs into ExpressionForms of SparseRanges of character codes.  

         @specifications.each do |name, spec|
            next unless spec.type == "string_spec"
            @string_defs[name] = StringDescriptor.new( create_name(spec.name), process_string_data(spec.definition, [name]) ) unless @string_defs.member?(name)
            
            warn_nyi( "skipping contraindications on string -- these are only done here, so must be done for every string" )
         end
         
         if false then
            @string_defs.each do |name, string_descriptor|
               string_descriptor.display( $stdout )
               $stdout.end_line
               $stdout.puts ""
            end
         end


         #
         # Resolve group specs into Group objects.
         
         @specifications.each do |name, spec|
            next unless spec.type.name == "group_spec"
            @group_defs[name] = process_group_data( spec, [name] ) unless @group_defs.member?(name)
            @group_defs[name].name = create_name(spec.name)
         end
            
         
         #
         # Resolve rule specs into Rules. 

         @specifications.each do |name, spec|
            next unless spec.type.name == "rule_spec"
                  
            #
            # Create the rule.
            
            transformation_set     = []
            @pending_transforms    = []
            @naming_contexts[name] = NamingContext.new( self )
            @rule_defs[name]       = Rule.new( create_name(spec.name), process_rule_expression(spec.expression, @naming_contexts[name], transformation_set, name) )
      
            #
            # Process any directives.
            
            spec.directives.each do |directive|
               case directive.type.name
                  when "associativity_directive"
                     case directive.direction.text
                        when "left"
                           @rule_defs[name].associativity = :left
                        when "right"
                           @rule_defs[name].associativity = :right
                        when "none"
                           @rule_defs[name].associativity = :none
                        else
                           nyi( "unsupported associativity [#{directive.direction.text}]", directive.direction )
                     end
                  else
                     nyi( "unsupported directive [#{directive.type}]", directive )
               end
            end
            
            #
            # Commit the naming context into the Rule.
      
            @naming_contexts[name].commit( @rule_defs[name] )

            #
            # Process any implicit transformations.  At present, this means the collection of * and + 
            # terms into a list.  We'll use a transformation in the form:
            #    @plural_name = @tree_slot/{@_tree|@singular_name}[!pluralization_type]
            # We can use this simplified npath expression because we always construct the Pluralization
            # in the same way -- with one singular name mapping to one plural name, regardles of slot
            # type.
            
            @rule_defs[name].each_plural_import do |tree_slot, pluralization, singular_name, plural_name|
               @rule_defs[name].transformations << validate_transform( name,
                  Grammar.assignment_transform(
                     Grammar.npath_slot_exp(plural_name),
                     Grammar.npath_predicate_exp(
                        Grammar.npath_path_exp( 
                           Grammar.npath_slot_exp(tree_slot), 
                           Grammar.npath_tclose_exp( Grammar.npath_branch_exp(Grammar.npath_slot_exp("_tree"), Grammar.npath_slot_exp(singular_name)) )
                        ),
                        Grammar.npred_negation_exp( Grammar.npred_type_exp(pluralization.name.name) )
                     )
                  )
               )
            end

            #
            # Process any explicit transformations.

            if spec.slot_filled?("transformation_specs") then
               spec.transformation_specs.each do |transformation_spec|
                  @rule_defs[name].transformations << validate_transform( name, transformation_spec )
               end
            end
            
         end
         
         
         #
         # Apply the priority setting.

         if @grammar_spec.priority.direction.text == "ascending" then
            @string_defs.reverse!
            @rule_defs.reverse!
            @group_defs.reverse!
            @reorder_specs.reverse!
            @reorder_specs.each do |spec|
               spec.reorder_levels.reverse!
            end
         else
            assert( @grammar_spec.priority.direction.text == "descending", "there's only two choices for this" )
         end
         
         
         #
         # Display the work, if appropriate.

         if false then
            @rule_defs.each do |name, definition|
               definition.display( $stdout )
               $stdout.end_line
               $stdout.puts
            end
         end
            
         if false then
            @string_defs.each do |name, string_descriptor|
               string_descriptor.display( $stdout )
               $stdout.end_line
               $stdout.puts ""
            end
         end
         
         
         #
         # Assign rule priorities.
         
         prioritize_rules()
         
         
         #
         # Build the Grammar Model.

         grammar = RCC::Model::Grammar.new( @grammar_spec.name.text )
         @string_defs.each {|name, definition| grammar.add_string(definition.name, definition)}
         @rule_defs.each{|name, definition| grammar.add_element(definition)}
         @group_defs.each  {|name, definition| grammar.add_group(definition)}


         #
         # Finally, process options.  We do this last for convenience.
         
         @grammar_spec.options.each do |option|
            case option.type.name
               
               when "start_rule"
                  if @rule_defs[option.rule_name.text].is_a?(Rule) then
                     grammar.start_rule_name = create_name(option.rule_name)
                  else
                     nyi( "error handling for bad start_rule [#{option.rule_name.text}]" )
                  end
                  
               when "ignore_switch"
                  if @string_defs.member?(option.name.text) then
                     name = create_name( option.name )
                     grammar.ignore_symbols << name unless grammar.ignore_symbols.member?(name)
                  else
                     nyi( "error handling for bad ignore switch [#{option.ignore_switch.text}]" )
                  end
                  
               when "backtracking_switch"
                  warn_nyi( "backtracking switch support (isn't this going away?)" )
               else
                  nyi( "support for option type [#{option.type}]", option )
            end
         end

         return grammar
      end
      
      
      #
      # pluralize()
      #  - pluralizes a name, according the grammar's rules
      
      def pluralize( name )
         warn_nyi( "support for pluralization guides in pluralize()" )
         return name.pluralize
      end
      
      
      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Model Building
    #---------------------------------------------------------------------------------------------------------------------
          
    protected


      #
      # register_specs()
      #  - registers specs with a namespace, recursing with a new namespace for each nested :namespace_spec
      #  - links each spec with its namespace
      #  - registers specs with the global @specs_by_name

      def register_specs( work_queue )
         until work_queue.empty?
            node = work_queue.shift
            case node.type.name
               when "section_spec"
                  node.specifications.reverse.each do |spec| 
                     work_queue.unshift spec 
                  end

               when "strings_spec"
                  work_queue = node.string_specs + work_queue if node.slot_filled?("string_specs")
               when "macros_spec"
                  work_queue = node.macro_specs + work_queue if node.slot_filled?("macro_specs")
                  warn_nyi "ModelBuilder: macro_specs are not being validated, currently"
                  
               when "string_spec", "macro_spec", "rule_spec", "group_spec"
                  if @specifications.member?(node.name.text) then
                     nyi( "error handling for duplicate name [#{node.name.text}]" )
                  else
                     @specifications[node.name.text] = node
                     
                     if node.type == "group_spec" then
                        node.specifications.reverse.each do |spec|
                           work_queue.unshift spec
                        end
                     end
                  end
                  
               when "spec_reference"
                  # no op -- this is just a side-effect of :group_spec processing
                  
               when "reorder_spec"
                  @reorder_specs << node

               else
                  nyi( "support for node type [#{node.type}]", node )
            end
         end
      end
      
      
      #
      # integrate_transformations()
      #  - links supplementary transformation specs into the rule_specs
      
      def integrate_transformations( transformation_sets )
         transformation_sets.each do |transformation_set|
            rule_name = transformation_set.rule_name.text
            
            if @specifications.member?(rule_name) and @specifications[rule_name].type.name == "rule_spec" then
               rule_spec = @specifications[rule_name]
               rule_spec.transformation_specs = [] if rule_spec.transformation_specs.nil?
               rule_spec.transformation_specs.concat( transformation_set.transformation_specs )
            else
               nyi( "error handling for missing transformation set target [#{rule_name}]" )
            end
         end
      end
         
      
      #
      # prioritize_rules()
      #  - assigns a priority to each rule in this grammar, based on rule order and :reorder_specs
      #  - earlier rules have higher priority than later rules, unless adjusted by a :reorder_spec
      #  - note that :reorder_specs can only reference rules in this grammar!
      
      def prioritize_rules()
         
         #
         # Process all :reorder_specs.  The top row of each table form roots of the DAG.
         # We test for cycles as we go -- there can't be any.  
         
         root_sets = []
         hierarchy = Util::DirectedAcyclicGraph.new( false )
         @reorder_specs.each do |spec|
            previous_level = []
            spec.reorder_levels.each do |level|
               
               #
               # Collect rule reference TO RULES IN THIS GRAMMAR ONLY.  Rule priority is about
               # rule production.  A grammar can use rules from other grammars, but can't PRODUCE
               # rules from other grammars, so local rules only need apply.  This is only an issue
               # for groups, where we'll just skip anything that isn't a local Rule.
               
               current_level = []
               level.references.each do |name_token|
                  name = name_token.text
                  if @rule_defs.member?(name) then
                     current_level << name
                  elsif @group_defs.member?(name) then
                     @group_defs[name].member_references.each do |reference|
                        if reference.is_a?(RuleReference) then
                           unless (reference.symbol_name.grammar.exists? and reference.symbol_name.grammar != @name)
                              current_level << reference.symbol_name.name
                           end
                        end
                     end
                  end
               end
               
               #
               # Everything in the current_level is linked to everything in the previous_level.  If 
               # there is no previous_level, then we'll register the names as points.
               
               if previous_level.empty? then
                  root_sets << current_level
                  current_level.each do |name|
                     hierarchy.register_point( name )
                  end
               else
                  previous_level.each do |parent_name|
                     current_level.each do |child_name|
                        if hierarchy.would_cycle?(parent_name, child_name) then
                           nyi( "error handling for precedence cycle [#{parent_name}] to [#{child_name}]" )
                        else
                           hierarchy.register( parent_name, child_name )
                        end
                     end
                  end
               end
               
               previous_level = current_level
            end
         end
         
         
         #
         # Now, we want to integrate the prioritized rules back into the overall hierarchy, and we
         # want to preserve as much of the original ordering as possible.  We do this by looking
         # within the prioritized rules at each layer and picking the highest priority for each
         # subtree, then inserting that layer at that index, shifting all the unprioritized rules 
         # down.
         #
         # I think some examples might help explain what I mean.
         #
         # Rules: a, b, c, d, e, f, g, h        | Rules: a, b, c, d, e, f
         # Order: 1, 2, 3, 4, 5, 6, 7, 8        | Order: 1, 2, 3, 4, 5, 6
         #                                      |
         # Prec table 1:                        | Prec table 1:
         #   d                                  |   b c
         #   e g                                |   e f
         # Prec table 2:                        | 
         #   h                                  | 
         #   d                                  | 
         #   g                                  | 
         #                                      |
         # DAG layers and original order:       | DAG layers and original order:
         #   h         8                        |  b c       2 3
         #   d         4                        |  e f       5 6
         #  e g       5 7                       |
         #
         # So, with these two examples, we want to reinsert the DAG elements back into the order
         # so that the DAG's hierarchy is respected, while -- as much as possible -- not disturbing 
         # the original order.  At each layer of the DAG, we look down the tree and find the highest
         # priority original position, and that is where we insert that layer.  So
         #
         # insertion_points:                    | insertion_points:
         #  4, 4, 5                             |  2, 5
         #
         # Now, obviously we can't insert two layers at the same point, so for the left example,
         # we'll need to adjust the second layer down a level, which will then cascade to the third
         # layer.  And as there is no room between those insertion points, any rules originally at
         # levels 4, 5, or 6 must be shifted down as well.
         #
         # For the right example, notice that rule 4 doesn't need to be disturbed by the
         # the prioritization of either layer, as there is space between insertion points 2 and 5.
         # So we leave it in that position.
         #
         # insertion_points:                    | insertion_points:
         #  4, 5, 6                             |  2, 5
         #
         # Finally, after integrating the default and prioritized rules, we get:
         #  1: a                                |  1: a
         #  2: b                                |  2: b c
         #  3: c                                |  3: d
         #  4: h                                |  4: e f
         #  5: d                                |
         #  6: e g                              |
         #  7: f                                |
         
         all_rules     = []
         default_rules = []
         
         @rule_defs.each do |name, element|
            name = name.to_s
            
            if element.is_a?(Rule) then
               all_rules     << name
               default_rules << name unless hierarchy.node?(name)
            end
         end


         #
         # Next we collect the raw insertion point data for the precedence data.  But there's another 
         # wrinkle.  Up top, we merged all the precedence tables into one DAG, so we could find loops
         # and inter-relationships between the precedence tables.  However, if some elements don't link
         # up, we don't want to prioritize all the independent trees to the same level -- we want to
         # preserve as much of the original ordering as possible.  So we have to process each tree separately,
         # then interleave the data back together.
         
         insertion_point_sets = []
         insertion_layer_sets = []
         
         hierarchy.independent_trees(root_sets).each do |tree|
            insertion_points = []
            insertion_layers = []
            
            tree.each_layer_reverse do |layer|
               insertion_point = all_rules.length
               layer.each do |name|
                  insertion_point = min( insertion_point, all_rules.index(name) )
               end
               
               insertion_points.unshift min(insertion_point, insertion_points.empty? ? insertion_point : insertion_points[0])
               insertion_layers.unshift layer
            end
            
            insertion_point_sets << insertion_points
            insertion_layer_sets << insertion_layers
         end
         
         
         #
         # We interleave the data sets back together.  We want to do the interleaving by insertion_point.
         
         insertion_points = []
         insertion_layers = []

         until insertion_point_sets.empty? 
            tops  = insertion_point_sets.collect{|set| set[0]}
            min   = tops.inject(all_rules.length){|current, aggregate| min(current, aggregate)}
            index = tops.index( min )
            
            insertion_points << insertion_point_sets[index].shift
            insertion_layers << insertion_layer_sets[index].shift
            
            if insertion_point_sets[index].empty? then
               insertion_point_sets.delete_at(index)
               insertion_layer_sets.delete_at(index)
            end
         end
         
         
         #
         # Next, we need to adjust the insertion points so that every one is unique.
         
         last_insertion_point = -1
         insertion_points.each_index do |index|
            insertion_points[index] = last_insertion_point + 1 if insertion_points[index] <= last_insertion_point
            last_insertion_point = insertion_points[index]
         end
            
         
         #
         # Finally, we have to integrate the two systems by setting the priority on each Rule.  
         # We proceed one priority level at a time: if it is in the insertion_points list, we set 
         # the priority for all rules on that level to that number; otherwise, we shift a name off
         # the default_rules list and set its priority instead.
         
         (default_rules.length + insertion_layers.length).times do |i|
            if insertion_points.member?(i) then
               insertion_layers[insertion_points.index(i)].each do |name|
                  @rule_defs[name].priority = i
               end
            else
               default_rules.shift.each do |rule_name|
                  @rule_defs[rule_name].priority = i
               end
            end
         end
      end
      

      
      @@escape_sequences = { '\n' => "\n", '\r' => "\r", '\t' => "\t", "\\\\" => "\\" }

      
      #
      # process_string_data()
      #  - processes the body of a :string_spec into a ExpressionForm of SparseRanges
      
      def process_string_data( node, loop_detection = [] )
         result = nil
         
         case node.type.name
            when "sp_concat"
               result = create_sequence( process_string_data(node.tree, loop_detection), process_string_data(node.leaf, loop_detection) )

            when "sp_branch"
               result = create_branch_point( process_string_data(node.tree, loop_detection), process_string_data(node.leaf, loop_detection) )

            when "sp_reference"
               if resolution = resolve_string_reference(node.name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character/word_definition [#{node.name.text}]" )
               end

            when "sp_repeated"
               minimum = 0
               maximum = nil

               case node.repeat_count.text
                  when "?"
                     minimum = 0
                     maximum = 1
                  when "*"
                     minimum = 0
                     maximum = nil
                  when "+"
                     minimum = 1
                     maximum = nil
                  else
                     bug( "unsupported repeat_count [#{node.repeat_count}]")
               end

               result = create_repeater( process_string_data(node.string_descriptor, loop_detection), minimum, maximum )

            when "cs_characters", "cs_difference"
               result = create_sequence( process_character_data(node, loop_detection) )

            when "string"
               result = create_sequence()
               node.elements.each do |string_element|
                  result << process_string_data( string_element, loop_detection )
               end

            when "general_text"
               result = create_sequence()
               node.text.length.times do |i|
                  result << Util::SparseRange.new( node.text[i] )
               end

            when "escape_sequence"
               if @@escape_sequences.member?(node.text) then
                  result = create_sequence( Util::SparseRange.new(@@escape_sequences[node.text][0]) )
               else
                  result = create_sequence( Util::SparseRange.new(node.text[1]) )
               end

            when "unicode_sequence"
               result = create_sequence( Util::SparseRange.new(node.text.slice(2..-1).to_i(16)) )

            else
               nyi( "support for node type [#{node.type}]", node )
         end

         return result
      end
      
      
      #
      # resolve_string_reference()
      
      def resolve_string_reference( name_token, loop_detection = [] )
         resolution = nil
         name = name_token.text
         
         if @specifications.member?(name) then
            spec = @specifications[name]
            
            case spec.type.name
               when "string_spec"
                  unless @string_defs.member?(name)
                     if loop_detection.member?(name) then
                        nyi( "error handling for detected reference loop [#{name}]" )
                     else
                        if resolution = process_string_data(spec.definition, loop_detection + [name]) then
                           @string_defs[name] = StringDescriptor.new( create_name(name_token), resolution ) 
                        end
                     end
                  end
            
                  resolution = @string_defs[name].form
                  
               else
                  nyi( "error handling for string reference that resolves to non-string" )
            end
         end
         
         return resolution
      end
      
      
      #
      # process_character_data()
      #  - processes the body of a :character_set (or parts thereof) into a SparseRange
      
      def process_character_data( node, loop_detection = [] )
         result = nil
         
         case node.type.name
            when "cs_difference"
               result = process_character_data( node.lhs, loop_detection ) - process_character_data( node.rhs, loop_detection )
            
            when "cs_characters"
               result = Util::SparseRange.new()
               node.cs_elements.each do |element|
                  result += process_character_data( element, loop_detection )
               end
               
            when "cs_range"
               result = Util::SparseRange.new( process_character_data(node.from, loop_detection)..process_character_data(node.to, loop_detection) )
               
            when "cs_reference"
               if resolution = resolve_character_reference(node.name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character_definition [#{node.name.text}]" )
               end
      
            when "general_character"
               result = node.text[0]
               
            when "escape_sequence"
               if @@escape_sequences.member?(node.text) then
                  result = @@escape_sequences[node.text][0]
               else
                  result = node.text[1]
               end
               
            when "unicode_sequence"
               result = node.text.slice(2..-1).to_i(16)
              
            else
               nyi( "support for node type [#{node.type}]", node )
         end
         
         return result
      end
      
      
      #
      # resolve_character_reference()
      #  - returns a SparseRange representing the character defined by the specified name
      
      def resolve_character_reference( name_token, loop_detection = [] )
         resolution = nil
         name = name_token.text
      
         if @specifications.member?(name) then
            spec = @specifications[name]

            case spec.type.name
               when "string_spec"
                  unless @string_defs.member?(name)
                     if loop_detection.member?(name) then
                        nyi( "error handling for detected reference loop [#{name}]" )
                     else
                        if string_def = process_string_data(spec.definition, loop_detection + [name]) then
                           @string_defs[name] = StringDescriptor.new( create_name(name_token), string_def )
                        end
                     end
                  end
            
                  #
                  # We are called to produce a single SparseRange, not an ExpressionForm.  Burrow down to 
                  # that SparseRange, ensuring we never have to choose from multiple SparseRanges on the 
                  # way.
                  
                  form = @string_defs[name].form
                  until resolution.exists? or form.nil?
                     if form.element_count == 1 then
                        form.each_element {|child| form = child }
                        resolution = form if form.is_a?(Util::SparseRange)
                     else
                        nyi( "error handling for character reference to non-character", form )
                     end
                  end
                  
               else
                  nyi( "error handling for character reference that resolves to non character")
            end
         end
      
         return resolution
      end
      
            
      # 
      # process_group_data()
      #  - process they body of a :group_spec (or parts thereof) into a Group
      
      def process_group_data( node, loop_detection = [] )
         result = nil
         
         case node.type.name
            when "group_spec"
               result = Group.new()
               node.specifications.each do |spec|
                  if element = process_group_data(spec, loop_detection) then
                     result << element
                  else
                     nyi( "what happens here?" )
                  end
               end
               
            when "rule_spec"
               result = Group.new()
               result << RuleReference.new( create_name(node.name) )
      
            when "spec_reference"
               name = node.name.text
               if @specifications.member?(name) then
                  spec = @specifications[name]
                  
                  result = Group.new()
                  case spec.type.name
                     when "group_spec"
                        if @group_defs.member?(name) then
                           result << @group_defs[name]
                        else
                           
                           #
                           # If we have to process a :group_spec directly, we don't store the result.  This is because
                           # we flatten groups via transitive closure, and shortcut out if we detect a loop (ie. somebody
                           # "above us" is already processing it).  We don't want to store such partial results.
                           
                           unless loop_detection.member?(name)
                              result << process_group_data( spec, loop_detection + [name] )
                           end
                        end
                        
                     when "rule_spec"
                        result << RuleReference.new( create_name(node.name) )
                     when "string_spec"
                        result << StringReference.new( create_name(node.name) )
                     else
                        nyi( "error handling for group reference to macro or other ineligible name [#{name}]" )
                  end
               else
                  nyi( "error handling for missing rule/word/character reference in group [#{name}]", node )
               end
            else
               nyi( "support for node type [#{node.type}]", node )
         end
      
         return result
      end
      
      
      #
      # process_rule_expression()
      #  - process the body of a :rule :expression (or parts thereof) into an ExpressionForm
      #  - prepares for slot assignment by collecting naming information on every nameable element
      #     - at present, this includes symbolic elements and explicitly labelled constants
      
      def process_rule_expression( node, naming_context, transformation_set, rule_name )
         result = nil
         
         case node.type.name
            when "macro_call"
               result = process_rule_expression( process_macro_call(node), naming_context, transformation_set, rule_name )
      
            when "sequence_exp"
               result = create_sequence( 
                  process_rule_expression( node.tree, naming_context, transformation_set, rule_name ), 
                  process_rule_expression( node.leaf, naming_context, transformation_set, rule_name ) 
               )
      
            when "repeated_exp"
               case node.repeat_count.text
                  when "?"
                     element = process_rule_expression( node.expression, naming_context, transformation_set, rule_name )
                     result  = Util::ExpressionForms::Optional.new( element )
                     
                  when "*", "+"
                     
                     #
                     # We cannot process plural terms directly in this rule, as it has to be parsed in 
                     # a tree shape (that's the way LR parsers work).  So, we prepare to factor out the
                     # pluralized terms, first by processing them in a separate naming context.
                     
                     child_namer = NamingContext.new( self )
                     child_set   = []
                     child_form  = process_rule_expression( node.expression, child_namer, child_set, rule_name )
                     
                     #
                     # Next, we try to get a nice name for the out-factored rule.  If we can get a single
                     # term, and its plural form is not taken, we'll use that.  Otherwise, we'll generate
                     # a name.
                     
                     child_name = "_plural_#{@rule_defs.length}"
                     if child_form.element_count == 1 and [StringReference, RuleReference, GroupReference].member?(child_form[0].class) then
                        singular_name = child_form[0].symbol_name
                        plural_name   = pluralize( singular_name )
                        if @specifications.member?(plural_name) then
                           child_name = "_plural_of_#{singular_name}"
                        else
                           child_name = plural_name
                        end
                     elsif node.expression.slot_filled?("label") then
                        singular_name = node.expression.label.text
                        plural_name   = rule_name + "_" + pluralize( singular_name )
                        
                        unless @specifications.member?(plural_name)
                           child_name = plural_name
                        end
                     end
                     
                     #
                     # If the name is already in the @rule_defs list, then this is a simple pluralization
                     # that has already been handled.  We won't duplicate the Pluralization.  Otherwise,
                     # it's new, and we save it.
                     
                     unless @rule_defs.member?(child_name) 
                        @rule_defs[child_name]       = Pluralization.new( create_name(child_name), child_form )
                        @naming_contexts[child_name] = child_namer
                        
                        child_namer.commit( @rule_defs[child_name] )
                     end
                     
                     result = @rule_defs[child_name].reference( node.repeat_count.text == "*" )
                     if @rule_defs[child_name].has_slots? then
                        naming_context.name( result, create_token("_tree_" + child_name) )
                        naming_context.import_pluralization( result, @naming_contexts[child_name] )
                     end
                     
                  else
                     bug( "unsupported repeat_count [#{node.repeat_count}]")
               end
                  
            when "branch_exp"
               result = create_branch_point(
                  process_rule_expression( node.tree, naming_context, transformation_set, rule_name ),
                  process_rule_expression( node.leaf, naming_context, transformation_set, rule_name )
               )
               
            when "gateway_exp"
               warn_nyi( "skipping gateway_exp, because I've no clue what to do with it" )
               result = create_sequence()
               
            when "local_commit"
               result = create_sequence( LocalCommit.new() )
            
            when "string_exp"
               word_name = anonymous_string( process_string_data(node.string) )
               symbol = StringReference.new( word_name )
               result = create_sequence( symbol )
               
               naming_context.name( symbol, node["label"], true ) if (node.slot_filled?("label") or naming_context.explicit_label_pending?)
            
            when "reference_exp"
               referenced_name = node.name.text
               if @specifications.member?(referenced_name) then
                  spec = @specifications[referenced_name]
                  
                  if spec.type == "macro_spec" then

                     #
                     # Expand the macro and recurse to process.  We use any explicit node label, or the macro
                     # name as implicit label.
                     
                     naming_context.apply_label(node.label.exists? ? node.label : node.name, node.label.exists?) do
                        result = process_rule_expression( process_macro_call(node), naming_context, transformation_set, rule_name )
                     end
                     
                  else
                     
                     #
                     # All references qualify for slots.  If no explicit label is supplied, we go with the source
                     # name (not anything it might have resolved to).

                     naming_context.apply_label(node["label"], true) do
                        symbol = nil
                        case spec.type.name
                           when "string_spec"
                              symbol = StringReference.new( create_name(node.name) )
                        
                           when "rule_spec"
                              symbol = RuleReference.new( create_name(node.name) )
                           
                           when "group_spec"
                              symbol = GroupReference.new( @group_defs[node.name.text] )
                           
                           else  
                              nyi( "error handling for invalid referenced name", referenced_name )
                        end
                           
                        result = create_sequence( symbol )
                        naming_context.name( symbol, node.name )
                     end
                  end
                  
               else
                  nyi( "error handling for missing referenced name [#{referenced_name}]")
               end
            
            when "group_exp"
               naming_context.apply_label(node.label, true) do
                  result = process_rule_expression( node.expression, naming_context, transformation_set, rule_name )
               end
               
            when "variable_exp"
               nyi( "error handling for variable in regular rule" )
               
            when "transclusion"
               nyi( "error handling for transclusion in regular rule" )
               
            else
               nyi( "support for node type [#{node.type}]", node )
         end
         
         return result
      end
      
      
      #
      # process_macro_call()
      #  - processes a macro_call spec or a reference to a zero-parameter macro
      #  - returns a list of :expression elements for further processing 
      
      def process_macro_call( call_exp )
         parameters = []
         body       = nil
         macro_name = nil
         
         case call_exp.type.name
            when "reference_exp"
               macro_name = call_exp.name.text        # NB: the label is being handled elsewhere!
            when "macro_call"
               macro_name = call_exp.macro_name.text
               parameters = call_exp.parameters 
               body       = call_exp.body if call_exp.slot_filled?("body")
            else
               bug( "why are you passing me a [#{call_exp.type}]?" )
         end
         
         
         nyi( "error handling for undefined macro call [#{macro_name}]" ) unless @specifications.member?(macro_name) 
         nyi( "error handling for bad macro call [#{macro_name}]"       ) unless @specifications[macro_name].type == "macro_spec"
         macro_spec = @specifications[macro_name]
         
         #
         # Validate the parameter counts and then assign them to slots.
         
         if parameters.length != macro_spec.parameter_definitions.length then
            nyi( "error handling for macro call parameter count mismatch (found #{parameters.length}; expected #{macro_spec.parameter_definitions.length})" )
         end
         
         parameter_lookup = {}
         parameters.length.times do |i|
            parameter_lookup[macro_spec.parameter_definitions[i].text] = parameters[i]
         end
         
         #
         # Process the macro body by creating a copy with all variable and transclusion
         # nodes replaced appropriately.
         
         return macro_spec.expression.duplicate do |node|
            case node.type.name
               when "transclusion"
                  nyi( "error handling for missing macro_call body" ) if body.nil?
                  body
               
               when "variable_exp"
                  nyi( "error handling for non-existent macro parameter definition [#{node.name.text}] in [#{parameter_lookup.keys.join(", ")}]" ) unless parameter_lookup.member?(node.name.text)
                  if node.label.nil? then
                     parameter_lookup[node.name.text]
                  else
                     BootstrapGrammar.group_exp( parameter_lookup[node.name.text], node.label )
                  end
      
               else
                  node
            end
         end
      end
      
      

      #
      # validate_transform()
      #  - validates a single transformation_spec ASN for use with a Rule
      #  - adds _type_name with a Name to appropriate nodes
      
      def validate_transform( rule, spec )
         warn_nyi( "transformation validations" )
         
         case spec.type.name
            
         when "assignment_transform", "append_transform"
            validate_transform( rule, spec.source )
            validate_transform( rule, spec.destination )
            
            
         when "npath_predicate_exp"
            validate_transform( rule, spec.npath )
            validate_transform( rule, spec.npred )
         when "npath_path_exp", "npath_branch_exp"
            validate_transform( rule, spec.tree )
            validate_transform( rule, spec.leaf )
         when "npath_tclose_exp"
            validate_transform( rule, spec.npath )
         when "npath_slot_exp", "npath_self_exp"
            # no op, for now
            
            
         when "npred_type_exp"
            spec.define_slot( "_type_name", create_name(spec.type_name) )
         when "npred_slot_exp"
            # no op, for now
         when "npred_negation_exp"
            validate_transform( rule, spec.npred )
         when "npred_or_exp", "npred_and_exp"
            validate_transform( rule, spec.tree )
            validate_transform( rule, spec.leaf )
         else
            nyi( "support for transform element [#{spec.type.name}]", spec )
         end
         
         return spec
      end
      
      
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Reference support
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
    
      #
      # anonymous_string()
      #  - given a string definition (ExpressionForm of SparseRanges), looks up/registers it under an
      #    anonymous name and returns the name
      
      def anonymous_string( string_def )

         #
         # Covert the string_def back into a string, if possible.
         
         string = ""
         string_def.each_element do |element|
            if element.is_a?(Util::SparseRange) and element.length == 1 then
               string << element.first
            else
               string = nil
               break
            end
         end
         
         
         #
         # Produce a StringDescriptor and register it appropriately.
         
         name = nil
         if string.nil? or string.empty? then
            name = Name.new( "_literal_" + @string_defs.length.to_s, @name )
         else
            name = Name.new( string )
         end
            
         @string_defs[name] = StringDescriptor.new( name, string_def, false ) unless @string_defs.member?(name)
         return name
      end
      
      




    #---------------------------------------------------------------------------------------------------------------------
    # General support
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
      
      #
      # create_sequence()
      #  - returns an ExpressionForms::Sequence of its parameters
      
      def create_sequence( *elements )
         return Util::ExpressionForms::Sequence.new( *elements )
      end
      
      
      #
      # create_branch_point()
      #  - returns an ExpressionForms::BranchPoint of its parameters
      
      def create_branch_point( *elements )
         return Util::ExpressionForms::BranchPoint.new( *elements )
      end
      
   
      #
      # create_repeater()
      #  - returns an ExpressionForms::Repeater of its parameters
      
      def create_repeater( element, minimum, maximum )
         return Util::ExpressionForms::Repeater.new( element, minimum, maximum )
      end
      
      
      #
      # create_token()
      #  - returns a Token for internal use
      
      def create_token( text )
         return Scanner::Artifacts::Nodes::Token.new( text, nil, 0, 0, 0, nil )
      end


      #
      # create_name()
      #  - returns a symbolic Name
      
      def create_name( name, source_token = nil )
         if name.is_a?(Token) then
            source_token = name if source_token.nil?
            name = name.text
         end
         
         name =  Name.new(name, @name, source_token)
         yield( name ) if block_given?
         return name
      end
      
      
    
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
