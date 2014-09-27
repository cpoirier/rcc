#!/usr/bin/env ruby
#================================================================================================================================
# RCC
# Copyright 2007-2008 Chris Poirier (cpoirier@gmail.com)
# 
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the 
# License.  You may obtain a copy of the License at
#    http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" 
# BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the License for the specific language 
# governing permissions and limitations under the License.
#================================================================================================================================

require "#{File.expand_path(__FILE__).split("/system/")[0..-2].join("/system/")}/system/environment.rb"
require "#{RCC_LIBDIR}/scanner/artifacts/name.rb"
require "#{RCC_LIBDIR}/languages/grammar/grammar.rb"
require "#{RCC_LIBDIR}/languages/grammar/naming_context.rb"
require "#{RCC_LIBDIR}/util/sparse_range.rb"
require "#{RCC_LIBDIR}/util/directed_acyclic_graph.rb"
require "#{RCC_LIBDIR}/util/expression_forms/expression_form.rb"
require "#{RCC_LIBDIR}/model/model.rb"


module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class GrammarBuilder
 #  - builds an RCC::Model::Grammar from an AST parsed from a grammar source file

   class GrammarBuilder
      
      Node              = RCC::Scanner::Artifacts::Node
      Token             = RCC::Scanner::Artifacts::Nodes::Token
      Name              = RCC::Scanner::Artifacts::Name
      Group             = RCC::Model::Elements::Group
      Rule              = RCC::Model::Elements::Rule
      Subrule           = RCC::Model::Elements::Subrule
      Pattern           = RCC::Model::Elements::Pattern
      Subpattern        = RCC::Model::Elements::Subpattern
      CharacterRange    = RCC::Model::Elements::CharacterRange
      Reference         = RCC::Model::Markers::Reference
      LocalCommit       = RCC::Model::Markers::LocalCommit      
      GatewayMarker     = RCC::Model::Markers::GatewayMarker
      
      @@escape_sequences = { '\n' => "\n", '\r' => "\r", '\t' => "\t", "\\\\" => "\\" }
    
      
      
      
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
         @reorder_specs       = []
         @discardable         = []
         
         @pattern_defs        = Util::OrderedHash.new()       # name => Pattern 
         @group_defs          = Util::OrderedHash.new()       # name => Group
         @rule_defs           = Util::OrderedHash.new()       # name => Rule
         @naming_contexts     = Util::OrderedHash.new()       # name => naming context data
      end
      
      
      
      #
      # resolve( name )
      #  - resolves the specified name into a Pattern, Rule, or Group
      
      def resolve( name )
         name = name.name if name.is_a?(Name)
         
         if @pattern_defs.member?(name) then
            return @pattern_defs[name]
         elsif @rule_defs.member?(name) then
            return @rule_defs[name]
         elsif @group_defs.member?(name) then
            return @group_defs[name]
         end
         
         return nil
      end
      
      



      #
      # build_model()
      #  - builds the Model::Grammar from specs
      
      def build_model()
         
         #
         # Register the grammar specifications (only).  Only do this on the first call.
         
         if @specifications.empty? then
            register_specs( @grammar_spec.specifications, build_discard_list(@grammar_spec.options) ) 
            integrate_transformations( @grammar_spec.transformations.transformation_sets ) if @grammar_spec.slot_filled?("transformations")
         end
         

         #
         # Resolve group specs into Group objects.
         
         @specifications.each do |name, spec|
            next unless spec.type.name == "group_spec"
            @group_defs[name] = Group.new( create_name(spec.name), process_group_data(spec, [name]) )
         end
            
         
         #
         # Resolve rule specs into Rules. 

         @specifications.each do |name, spec|
            next unless spec.type.name == "rule_spec"
            
            #
            # Create the rule.
            
            if string_pattern?(spec) then
               register( Pattern.new(name_pattern(name), process_string_pattern(spec.expression.string_pattern, name)) ) unless @pattern_defs.member?(name)
            else
               transformation_set     = []
               @pending_transforms    = []
               @naming_contexts[name] = NamingContext.new( self )
               @rule_defs[name]       = Rule.new( create_name(spec.name), process_rule_expression(spec.expression, @naming_contexts[name], transformation_set, name, spec._discard_list), spec._discard_list )
                  
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
               # We can use this simplified npath expression because we always construct the PluralSubrule
               # in the same way -- with one singular name mapping to one plural name, regardles of slot
               # type.
            
               @rule_defs[name].each_plural_import do |tree_slot, subrule_name, singular_name, plural_name|
                  @rule_defs[name].transformations << validate_transform( name,
                     Grammar.assignment_transform(
                        Grammar.npath_slot_exp(plural_name),
                        Grammar.npath_predicate_exp(
                           Grammar.npath_path_exp( 
                              Grammar.npath_slot_exp(tree_slot), 
                              Grammar.npath_tclose_exp( Grammar.npath_branch_exp(Grammar.npath_slot_exp("__tree"), Grammar.npath_slot_exp(singular_name)) )
                           ),
                           Grammar.npred_negation_exp( Grammar.npred_type_exp(subrule_name.name) )
                        )
                     )
                  )
                  
                  @rule_defs[name].transformations << validate_transform( name,
                     Grammar.unset_transform( Grammar.npath_slot_exp(tree_slot) )
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
         end
         
         
         #
         # Apply the priority setting.

         if @grammar_spec.priority.direction.text == "ascending" then
            @pattern_defs.reverse!
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
         # Assign rule priorities.
         
         prioritize_rules()

         @rule_defs.each do |name, definition|
            definition.priority = 1 if definition.is_a?(Subrule)
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
            @pattern_defs.each do |name, pattern|
               pattern.display( $stdout )
               $stdout.end_line
               $stdout.puts ""
            end
         end
         
         
         #
         # Build the Grammar Model.

         grammar = RCC::Model::Grammar.new( @grammar_spec.name.text )
         @pattern_defs.each {|name, definition| grammar.add_pattern(definition)}
         @rule_defs.each    {|name, definition| grammar.add_rule(definition)}
         @group_defs.each   {|name, definition| grammar.add_group(definition)}


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
                  
               when "discard_switch"
                  # no op -- dealt with elsewhere
                  
                  warn_nyi( "gateway expression check for corresponding discard?"    )
                  warn_nyi( "gateway expression exclusion at start AND end of rule?" )
                  
               else
                  nyi( "support for option type [#{option.type}]", option )
            end
         end
         
         @discardable.each do |name|
            nyi( "error handling for bad discard switch [#{name}]" ) unless (@pattern_defs.member?(name.name) or @rule_defs.member?(name.name))
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
      # string_pattern?()
      #  - returns true if the supplied rule_spec contains only a single string_pattern
      
      def string_pattern?( rule_spec )
         return (rule_spec.expression.type.name == "sp_exp" and !rule_spec.expression.slot_filled?("label") and rule_spec.directives.empty?)
      end
      
      
      #
      # character_range?()
      #  - returns true if the supplied rule_spec contains only a single character range string_pattern
      
      def character_range?( rule_spec )
         return false unless string_pattern?(rule_spec)
         return Grammar.node_has_type?(rule_spec.expression.string_pattern, "character_set")
      end
         

      #
      # register_specs()
      #  - registers specs with a namespace, recursing with a new namespace for each nested :namespace_spec
      #  - links each spec with its namespace
      #  - registers specs with the global @specs_by_name

      def register_specs( work_queue, grammar_discard_list = [] )
         until work_queue.empty?
            node = work_queue.shift
            case node.type.name
               when "section_spec"
                  section_discard_list = build_discard_list( node.options, node.slot_filled?("_discard_list") ? node._discard_list : grammar_discard_list )
                  # puts "SECTION [#{node.name}] discard list: #{section_discard_list.join(" ")}"
                  node.specifications.reverse.each do |spec| 
                     spec.define_slot( "_discard_list", section_discard_list )
                     work_queue.unshift spec 
                  end

               when "macros_spec"
                  work_queue = node.macro_specs + work_queue if node.slot_filled?("macro_specs")
                  warn_nyi "ModelBuilder: macro_specs are not being validated, currently"
                  
               when "macro_spec", "rule_spec", "group_spec"
                  if @specifications.member?(node.name.text) then
                     nyi( "error handling for duplicate name [#{node.name.text}]" )
                  else
                     node.define_slot("_discard_list", grammar_discard_list) unless node.slot_defined?("_discard_list")
                     @specifications[node.name.text] = node
                     
                     if node.type == "group_spec" then
                        node.specifications.reverse.each do |spec|
                           spec.define_slot("_discard_list", node._discard_list)
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
      # build_discard_list()
      
      def build_discard_list( options, existing = [] )
         list = [] + existing
         
         options.each do |option|
            case option.type.name
               when "discard_switch"
                  name = create_name( option.name )
                  list         << name unless list.member?(name)
                  @discardable << name unless @discardable.member?(name)
               when "no_discard"
                  list = []
            end
         end
         
         return list
      end
      
      
      # 
      # process_group_data()
      #  - process the body of a :group_spec (or parts thereof) into an array of References
      
      def process_group_data( node, loop_detection = [] )
         result = []
         
         case node.type.name
            when "group_spec"
               node.specifications.each do |spec|
                  if elements = process_group_data(spec, loop_detection) then
                     result.concat elements
                  else
                     nyi( "what happens here?" )
                  end
               end
               
            when "rule_spec"
               result << Reference.new(create_name(node.name))
      
            when "spec_reference"
               name = node.name.text
               if @specifications.member?(name) then
                  spec = @specifications[name]
                  
                  case spec.type.name
                     when "group_spec"
                        if @group_defs.member?(name) then
                           result.concat @group_defs[name].member_references.collect{|r| r.clone()}
                        else
                           
                           #
                           # If we have to process a :group_spec directly, we don't store the result.  This is because
                           # we flatten groups via transitive closure, and shortcut out if we detect a loop (ie. somebody
                           # "above us" is already processing it).  We don't want to store such partial results.
                           
                           unless loop_detection.member?(name)
                              result.concat process_group_data(spec, loop_detection + [name])
                           end
                        end
                        
                     when "rule_spec"
                        result << Reference.new( create_name(node.name) )
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
      # process_string_pattern()
      #  - processes the body of a string_pattern into an ExpressionForm of CharacterRanges and References
      #  - may create and register Patterns as a side effect
      
      def process_string_pattern( node, rule_name, loop_detection = nil )
         loop_detection = [rule_name] if loop_detection.nil?
         result = nil
         
         case node.type.name
            when "sp_sequence"
               result = create_sequence( process_string_pattern(node.tree, rule_name, loop_detection), process_string_pattern(node.leaf, rule_name, loop_detection) )

            when "sp_branch"
               result = create_branch_point( process_string_pattern(node.tree, rule_name, loop_detection), process_string_pattern(node.leaf, rule_name, loop_detection) )

            when "sp_repeated"
               case node.repeat_count.text
               when "?"
                  result = create_optional( process_string_pattern(node.string_pattern, rule_name, loop_detection) )
               when "+", "*"
                  singular_pattern = process_string_pattern( node.string_pattern, rule_name, loop_detection )
                  plural_pattern = register( Subpattern.new(name_pattern(rule_name, true), singular_pattern) )
                  
                  result = create_sequence( Reference.new(plural_pattern.name) )
                  result = create_optional(result) if node.repeat_count.text == "*"
               else
                  bug( "unsupported repeat_count [#{node.repeat_count}]")
               end
               
            when "sp_group"
               result = process_string_pattern( node.string_pattern, rule_name, loop_detection )

            when "cs_characters", "cs_difference"
               result = create_sequence( process_character_data(node, loop_detection) )

            else
               nyi( "support for node type [#{node.type}]", node )
         end

         return result
      end
      
      
      #
      # process_character_data()
      #  - processes the body of a :character_set (or parts thereof) into a CharacterRange
      
      def process_character_data( node, loop_detection = [] )
         result = nil
         
         case node.type.name
            when "cs_difference"
               result = process_character_data( node.lhs, loop_detection ) - process_character_data( node.rhs, loop_detection )
            
            when "cs_characters"
               result = CharacterRange.new()
               node.cs_elements.each do |element|
                  if Grammar.node_has_type?(element, "character") then
                     result += process_character( element )
                  else
                     result += process_character_data( element, loop_detection )
                  end
               end
               
            when "cs_range"
               result = CharacterRange.new( process_character(node.from)..process_character(node.to) )
               
            when "cs_reference"
               if resolution = resolve_character_reference(node.name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character_definition [#{node.name.text}]" )
               end
               
            else
               nyi( "support for node type [#{node.type}]", node )
         end

         return result
      end


      #
      # process_character()
      #  - returns a character code for the specified character node
      
      def process_character( node )
         result = nil
         
         case node.type.name
            when "general_character"
               result = node.text.codepoints[0]
               
            when "escape_sequence"
               if @@escape_sequences.member?(node.text) then
                  result = @@escape_sequences[node.text].codepoints[0]
               else
                  result = node.text.codepoints[1]
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
      #  - returns a CharacterRange representing the character defined by the specified name
      
      def resolve_character_reference( name_token, loop_detection = [] )
         resolution = nil
         name = name_token.text
      
         if @specifications.member?(name) then
            if loop_detection.member?(name) then
               nyi( "error handling for detected reference loop [#{name}]" )
            else
               loop_detection = loop_detection + [name]
               spec = @specifications[name]

               if spec.type.name == "rule_spec" and character_range?(spec) then
                  pattern = register( Pattern.new(name_pattern(name), process_string_pattern(spec.expression.string_pattern, name, loop_detection)) )
                  
                  #
                  # We are called to produce a single CharacterRange, not an ExpressionForm.  Burrow down to that
                  # CharacterRange, ensuring we never have to choose from multiple SparseRanges on the way.  This
                  # should already be guaranteed by character_range?(), but we'll check anyway.
                  
                  form = pattern.master_form
                  until resolution.exists? or form.nil?
                     if form.element_count == 1 then
                        form = form[0]
                        resolution = form if form.is_a?(CharacterRange)
                     else
                        break
                     end
                  end
               end
               
               if resolution.nil? then
                  nyi( "error handling for character reference that resolves to non-character [#{name}]", spec )
               end
            end
         end
      
         return resolution
      end
      
      
      #
      # process_rule_expression()
      #  - process the body of a rule_spec (or parts thereof) into an ExpressionForm
      #  - prepares for slot assignment by collecting naming information on every nameable element
      #     - at present, this includes symbolic elements and explicitly labelled constants
      
      def process_rule_expression( node, naming_context, transformation_set, rule_name, discard_list )
         result = nil
         
         case node.type.name
            when "macro_call"
               result = process_rule_expression( process_macro_call(node), naming_context, transformation_set, rule_name, discard_list )
      
            when "sequence_exp"
               result = create_sequence( 
                  process_rule_expression( node.tree, naming_context, transformation_set, rule_name, discard_list ), 
                  process_rule_expression( node.leaf, naming_context, transformation_set, rule_name, discard_list ) 
               )
      
            when "repeated_exp"
               case node.repeat_count.text
                  when "?"
                     element = process_rule_expression( node.expression, naming_context, transformation_set, rule_name, discard_list )
                     result  = create_optional( element )
                     
                  when "*", "+"
                     
                     #
                     # We cannot process plural terms directly in this rule, as it has to be parsed in 
                     # a tree shape (that's the way LR parsers work).  So, we prepare to factor out the
                     # pluralized terms, first by processing them in a separate naming context.
                     
                     child_namer = NamingContext.new( self )
                     child_set   = []
                     child_form  = process_rule_expression( node.expression, child_namer, child_set, rule_name, discard_list )
                     
                     #
                     # Next, we try to get a nice name for the out-factored rule.  If we can get a single
                     # term, and its plural form is not taken, we'll use that.  Otherwise, we'll generate
                     # a name.
                     
                     resolution = nil
                     element = child_form
                     until resolution.exists? or element.nil?
                        if element.element_count == 1 then
                           element = element[0]
                           resolution = element if element.is_a?(Reference)
                        else
                           break
                        end
                     end
                     
                     child_name = nil
                     warn_nyi( "discard list discrimination for factored terms" )
                     if resolution.set? then
                        child_name = create_name("#{child_form[0].symbol_name.name}__sequence")
                     elsif node.expression.slot_filled?("label") then
                        child_name = create_name("#{rule_name}__#{node.expression.label.text}__sequence")
                     else
                        child_name = name_rule(rule_name, true)
                     end
                     
                     #
                     # If the name is already in the @rule_defs list, then this is a simple pluralization that 
                     # has already been handled.  We won't duplicate the Subrule.  Otherwise, it's new, and we 
                     # save it.
                     
                     unless @rule_defs.member?(child_name.name) 
                        @rule_defs[child_name.name]       = Subrule.new( child_name, child_form, discard_list )
                        @naming_contexts[child_name.name] = child_namer
                        
                        child_namer.commit( @rule_defs[child_name.name] )
                     end

                     reference = Reference.new( child_name )
                     result = create_sequence(reference)
                     result = create_optional(result) if node.repeat_count.text == "*"

                     if @rule_defs[child_name.name].has_slots? then
                        naming_context.name( reference, create_token(child_name.name + "__tree") )
                        naming_context.import_pluralization( reference, @naming_contexts[child_name.name] )
                     end
                     
                  else
                     bug( "unsupported repeat_count [#{node.repeat_count}]")
               end
                  
            when "branch_exp"
               result = create_branch_point(
                  process_rule_expression( node.tree, naming_context, transformation_set, rule_name, discard_list ),
                  process_rule_expression( node.leaf, naming_context, transformation_set, rule_name, discard_list )
               )
               
            when "gateway_exp"
               name = node.word.text
               if !@specifications.member?(name) or @specifications[name].type.name == "group" then
                  nyi( "error handling for bad gateway" )
               else
                  result = create_sequence( GatewayMarker.new(create_name(node.word)) )
               end
               
            when "local_commit"
               result = create_sequence( LocalCommit.new() )
            
            when "string_exp"
               sequence = create_sequence()
               name     = ""
               node.string.elements.each do |string_element|
                  case string_element.type.name
                     when "general_text"
                        string_element.text.length.times do |i|
                           sequence << CharacterRange.new( string_element.characters[i] )
                        end
                        
                     when "escape_sequence"
                        if @@escape_sequences.member?(string_element.text) then
                           sequence << CharacterRange.new( @@escape_sequences[string_element.text][0] )
                        else
                           sequence << CharacterRange.new( string_element.characters[1] )
                        end
                     
                     when "unicode_sequence"
                        sequence << CharacterRange.new( string_element.text.slice(2..-1).to_i(16) )
                     else
                        nyi( "unsupport string element type [#{string_element.type.name}]", string_element )
                  end
                  
                  name += string_element.text
               end
               
               pattern = register( Pattern.new(Name.new(name), sequence) )
               symbol = Reference.new( pattern.name )
               result = create_sequence( symbol )
               
               naming_context.name( symbol, node.label, true ) if (node.slot_filled?("label") or naming_context.explicit_label_pending?)
               
            when "sp_exp"
               pattern_name = name_inline_pattern( rule_name )
               pattern_form = process_string_pattern( node.string_pattern, pattern_name )

               optional = false
               if pattern_form.optional? then
                  optional = true
                  if pattern_form.is_a?(Util::ExpressionForms::Optional) then
                     pattern_form = pattern_form.element
                  else
                     nyi( "error reporting for embedded optional pattern that can't be rule-ized", node.string_pattern )
                  end
               end
               
               pattern = register( Pattern.new(pattern_name, pattern_form) )
               symbol  = Reference.new( pattern.name )
               symbol  = create_optional(symbol) if optional
               result  = create_sequence( symbol )
               
               naming_context.name( symbol, node.label, true ) if (node.slot_filled?("label") or naming_context.explicit_label_pending?)
            
            when "reference_exp"
               referenced_name = node.name.text
               if @specifications.member?(referenced_name) then
                  spec = @specifications[referenced_name]
                  
                  if spec.type == "macro_spec" then

                     #
                     # Expand the macro and recurse to process.  We use any explicit node label, or the macro
                     # name as implicit label.
                     
                     naming_context.apply_label(node.label.exists? ? node.label : node.name, node.label.exists?) do
                        result = process_rule_expression( process_macro_call(node), naming_context, transformation_set, rule_name, discard_list )
                     end
                     
                  else
                     
                     #
                     # All references qualify for slots.  If no explicit label is supplied, we go with the source
                     # name (not anything it might have resolved to).

                     naming_context.apply_label(node["label"], true) do
                        symbol = nil
                        case spec.type.name
                           when "rule_spec"
                              symbol = Reference.new( create_name(node.name) )
                           
                           when "group_spec"
                              symbol = Reference.new( create_name(node.name) )
                           
                           else  
                              nyi( "error handling for invalid referenced name", referenced_name )
                        end
                           
                        result = create_sequence( symbol )
                        naming_context.name( symbol, node.name )
                     end
                  end
                  
               else
                  nyi( "error handling for missing referenced name [#{referenced_name}]" )
               end
            
            when "group_exp"
               naming_context.apply_label(node.label, true) do
                  result = process_rule_expression( node.expression, naming_context, transformation_set, rule_name, discard_list )
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
                     Grammar.group_exp( parameter_lookup[node.name.text], node.label )
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
            
         when "unset_transform"
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
    # Object creation and management
    #---------------------------------------------------------------------------------------------------------------------

    protected

      #
      # register()
      #  - registers an object appropriately with the system
      
      def register( object, duplicates_are_normal = true )
         case object
         when Pattern
            if @pattern_defs.member?(object.name.name) then
               assert( duplicates_are_normal, "duplicate Pattern [#{object.name}]", object )
               object = @pattern_defs[object.name.name]
            else
               @pattern_defs[object.name.name] = object
            end
            
         when Rule
            if @rule_defs.member?(object.name.name) then
               assert( duplicates_are_normal, "duplicate Rule [#{object.name}]", object )
               object = @rule_defs[object.name.name]
            else
               @rule_defs[object.name.name] = object
            end
            
         else
            nyi( "don't know how to register an object of type [#{object.class.name}]" )
         end
         
         return object
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
      
      
      #
      # name_pattern()
      #  - returns a usable Name for a Pattern
      #  - optionally gives the name a unique numeric offset 
      
      def name_pattern( base_name, subpattern = false )
         name = base_name.is_a?(Name) ? base_name.name : base_name

         if subpattern then
            attempt = ["#{name}__subpattern_", 1]
            attempt[1] += 1 while @pattern_defs.member?(attempt.join(""))
            
            name = attempt.join("")
         end

         return create_name(name)
      end
      
      
      # 
      # name_rule()
      #  - returns a usable Name for a Rule
      #  - optional gives the name a unique numeric offset
      
      def name_rule( base_name, subrule = false )
         name = base_name.is_a?(Name) ? base_name.name : base_name
         
         if subrule then
            attempt = ["#{name}__subrule_", 1]
            attempt[1] += 1 while @rule_defs.member?(attempt.join(""))
            
            name = attempt.join("")
         end
         
         return create_name(name)
      end
      
      
      #
      # name_inline_pattern()
      #  - returns a usable Name for a Pattern embedded in a Rule
      
      def name_inline_pattern( rule_name )
         name = rule_name.is_a?(Name) ? rule_name.name : rule_name

         attempt = ["#{name}__pattern_", 1]
         attempt[1] += 1 while @pattern_defs.member?(attempt.join(""))
         
         name = attempt.join("")
         return create_name(name)
      end
      
      
      
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
      # create_optional()
      #  - returns an ExpressionForms::Optional of its parameter
      
      def create_optional( element )
         return Util::ExpressionForms::Optional.new( element )
      end
      
      
      #
      # create_token()
      #  - returns a Token for internal use
      
      def create_token( text )
         return Scanner::Artifacts::Nodes::Token.new( text, nil, 0, 0, 0, nil )
      end







    #---------------------------------------------------------------------------------------------------------------------
    # Post Processing
    #---------------------------------------------------------------------------------------------------------------------

    protected
          
      
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
      

      
      
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
