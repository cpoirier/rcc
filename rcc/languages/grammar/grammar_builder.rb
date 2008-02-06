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
require "#{$RCCLIB}/util/namespace.rb"
require "#{$RCCLIB}/util/sparse_range.rb"
require "#{$RCCLIB}/util/expression_forms/expression_form.rb"
require "#{$RCCLIB}/model/symbol.rb"
require "#{$RCCLIB}/model/group.rb"


module RCC
module Languages
module Grammar

 
 #============================================================================================================================
 # class GrammarBuilder
 #  - builds an RCC::Model::Grammar from an AST parsed from a grammar source file

   class GrammarBuilder
      
      #
      # ::build()
      #  - given an AST of a grammar, builds a Model::Grammar or an error report
      
      def self.build( ast )
         builder = new()
         return builder.build_model( ast )
      end
      
      Node  = RCC::Scanner::Artifacts::Node
      
      
      
      
      
    #---------------------------------------------------------------------------------------------------------------------
    # Initialization
    #---------------------------------------------------------------------------------------------------------------------

      def initialize()
         @grammar = nil
         
         @specifications      = Util::OrderedHash.new()   # name => spec, in declaration order
         @option_specs        = []
         @pluralization_specs = Util::OrderedHash.new()
         
         @string_defs         = Util::OrderedHash.new()    # name => ExpressionForm result of processing a :string_spec
         @group_defs          = Util::OrderedHash.new()    # name => list of rule names in the group
         @rule_defs           = Util::OrderedHash.new()    # name => 
      end



      #
      # build_model()
      #  - given a AST of a grammar, returns a Model::Grammar or an error report
      
      def build_model( grammar_spec )
         assert( grammar_spec.type == :grammar_spec, "Um, perhaps you meant to pass a grammar_spec AST?" )
         
         #
         # Start by moving all of the specs into @specifications.
         
         register_specs( [grammar_spec] )
         

         #
         # Resolve string specs into ExpressionForms of SparseRanges of character codes.  

         @specifications.each do |name, spec|
            next unless spec.type == :string_spec
            @string_defs[name] = process_string_data( spec.definition, [name] ) unless @string_defs.member?(name)
         end
         
         if false then
            @string_defs.each do |name, definition|
               $stdout.puts "string_def #{name}:"
               $stdout.indent do 
                  definition.display($stdout)
               end
               $stdout.puts ""
            end
         end
         
         
         #
         # Resolve group specs into Group objects.  
         
         @specifications.each do |name, spec|
            next unless spec.type == :group_spec
            @group_defs[name] = process_group_data( spec, [name] ) unless @group_defs.member?(name)
         end
         
         if false then
            @group_defs.each do |name, definition|
               $stdout.puts "group_def #{name}:"
               $stdout.indent do
                  definition.display( $stdout )
               end
               $stdout.puts ""
            end
         end
         

         #
         # Resolve rule specs into ExpressionForms.  Note that we do them all here -- they are never
         # built via reference.
         
         @specifications.each do |name, spec|
            next unless spec.type == :rule_spec
            naming_context = []
            @rule_defs[name] = process_rule_expression( spec.expression, naming_context )
         
            #
            # Assign slots pass 1: delete any record with slot name "ignore".  For obvious reasons.
            
            naming_context.delete_if{|record| record[1].text == "ignore"}
            
            #
            # Assign slots pass 2: ensure no explicit slot name overlaps *any* other slot name.
            # That said, the *same* explicit slot name token maybe validly assigned to more than
            # one symbol.  For instance: (a|b|c):name.  We check the token object_ids to tell the
            # difference.  
            
            explicit_names = {}
            implicit_names = {}
            
            naming_context.each do |record|
               symbol, name_token, context_is_plural, name_is_explicit = *record
         
               name = name_token.text
               name = name.pluralize if context_is_plural
               
               if name_is_explicit then
                  if explicit_names.member?(name) and explicit_names[name][0][1].object_id != name_token.object_id then
                     nyi( "error handling for duplicate explicit slot name [#{name}]" )
                  elsif implicit_names.member?(name) then
                     nyi( "error handling for explicit slot name that conflicts with implicit slot name [#{name}]" )
                  else
                     explicit_names[name] = [] unless explicit_names.member?(name)
                     explicit_names[name] << record
                  end
               else
                  if explicit_names.member?(name) then
                     nyi( "error handling for explicit slot name that conflicts with implicit slot name [#{name}]" )
                  end
                  
                  implicit_names[name] = [] unless implicit_names.member?(name)
                  implicit_names[name] << record
               end
            end
            
            #
            # Assign slots pass 3: assign names.
            
            explicit_names.each do |name, records|
               records.each do |record|
                  record[0].slot_name = name
               end
            end
            
            implicit_names.each do |name, records|
               if records.length == 1 then
                  records[0][0].slot_name = name
               else
                  number = 1
                  records.each do |record|
                     record[0].slot_name = "#{name}_#{number}"
                     number += 1
                  end
               end
            end
         
            #
            # Deal with any transformations.
            
            STDERR.puts "skipping transformation on rule #{name}" if spec.slot_filled?(:transformation_specs)
         end
         
         if true then
            @rule_defs.each do |name, definition|
               $stdout.puts "rule_def #{name}:"
               $stdout.indent do
                  definition.display( $stdout )
               end
               $stdout.puts ""
            end
         end
         
         
         # #
         # # Now we can start building the Model.
         # 
         # @grammar = Model::Grammar.new( grammar_spec.name )
         # puts "DONE"
         # exit
         # 
      end


      #
      # register_specs()
      #  - registers specs with a namespace, recursing with a new namespace for each nested :namespace_spec
      #  - links each spec with its namespace
      #  - registers specs with the global @specs_by_name

      def register_specs( work_queue )
         until work_queue.empty?
            node = work_queue.shift
            case node.type
               when :grammar_spec, :section_spec
                  node.specifications.reverse.each do |spec| 
                     work_queue.unshift spec 
                  end

                  warn_nyi( "ModelBuilder: support for options" )
                  
               when :strings_spec
                  work_queue = node.string_specs + work_queue if node.slot_filled?(:string_specs)
               when :macros_spec
                  work_queue = node.macro_specs + work_queue if node.slot_filled?(:macro_specs)
                  warn_nyi "ModelBuilder: macro_specs are not being validated, currently"
                  
               when :string_spec, :macro_spec, :rule_spec, :group_spec
                  if @specifications.member?(node.name.text) then
                     nyi( "error handling for duplicate name [#{node.name.text}]" )
                  else
                     @specifications[node.name.text] = node
                     
                     if node.type == :group_spec then
                        node.specifications.reverse.each do |spec|
                           work_queue.unshift spec
                        end
                     end
                  end
                  
               when :spec_reference
                  # no op -- this is just a side-effect of :group_spec processing
                  
               when :precedence_spec
                  warn_nyi( "ModelBuilder: support to precendence markers" )
                  
               else
                  nyi( "support for node type [#{node.type}]", node )
            end
         end
      end




      
      

    #---------------------------------------------------------------------------------------------------------------------
    # Model Building
    #---------------------------------------------------------------------------------------------------------------------
          
    protected

      @@escape_sequences = { '\n' => "\n", '\r' => "\r", '\t' => "\t", "\\\\" => "\\" }
      
      
      #
      # process_string_data()
      #  - processes the body of a :string_spec into a ExpressionForm of SparseRanges
      
      def process_string_data( node, loop_detection = [] )
         result = nil
         
         case node.type
            when :sp_concat
               result = create_sequence( process_string_data(node.lhs, loop_detection), process_string_data(node.rhs, loop_detection) )

            when :sp_reference
               if resolution = resolve_string_reference(node.name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character/word_definition [#{node.name.text}]" )
               end

            when :sp_repeated
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

               result = create_repeater( process_string_data(node.string_pattern, loop_detection), minimum, maximum )

            when :cs_characters, :cs_difference
               result = create_sequence( process_character_data(node, loop_detection) )

            when :string
               result = create_sequence()
               node.string_elements.each do |string_element|
                  result << process_string_data( string_element, loop_detection )
               end

            when :general_text
               result = create_sequence()
               node.text.each do |character|
                  result << Util::SparseRange.new( character[0] )
               end

            when :escape_sequence
               if @@escape_sequences.member?(node.text) then
                  result = create_sequence( Util::SparseRange.new(@@escape_sequences[node.text][0]) )
               else
                  result = create_sequence( Util::SparseRange.new(node.text[1]) )
               end

            when :unicode_sequence
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
            
            case spec.type
               when :string_spec
                  unless @string_defs.member?(name)
                     if loop_detection.member?(name) then
                        nyi( "error handling for detected reference loop [#{name}]" )
                     else
                        if resolution = process_string_data(spec.definition, loop_detection + [name]) then
                           @string_defs[name] = resolution
                        end
                     end
                  end
            
                  resolution = @string_defs[name]
                  
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
         
         case node.type
            when :cs_difference
               result = process_character_data( node.lhs, loop_detection ) - process_character_data( node.rhs, loop_detection )
            
            when :cs_characters
               result = Util::SparseRange.new()
               node.cs_elements.each do |element|
                  result += process_character_data( element, loop_detection )
               end
               
            when :cs_range
               result = Util::SparseRange.new( process_character_data(node.from, loop_detection)..process_character_data(node.to, loop_detection) )
               
            when :cs_reference
               if resolution = resolve_character_reference(node.name, loop_detection) then
                  result = resolution
               else
                  nyi( "error handling for missing character_definition [node.name.text]" )
               end
      
            when :general_character
               result = node.text[0]
               
            when :escape_sequence
               if @@escape_sequences.member?(node.text) then
                  result = @@escape_sequences[node.text][0]
               else
                  result = node.text[1]
               end
               
            when :unicode_sequence
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

            case spec.type 
               when :string_spec
                  unless @string_defs.member?(name)
                     if loop_detection.member?(name) then
                        nyi( "error handling for detected reference loop [#{name}]" )
                     else
                        if string_def = process_string_data(spec.definition, loop_detection + [name]) then
                           @string_defs[name] = string_def
                        end
                     end
                  end
            
                  #
                  # We are called to produce a single SparseRange, not an ExpressionForm.  Burrow down to 
                  # that SparseRange, ensuring we never have to choose from multiple SparseRanges on the 
                  # way.
                  
                  form = @string_defs[name]
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
         
         case node.type
            when :group_spec
               result = Model::Group.new()
               node.specifications.each do |spec|
                  if element = process_group_data(spec, loop_detection) then
                     result << element
                  else
                     nyi( "what happens here?" )
                  end
               end
               
            when :rule_spec
               result = Model::Group.new()
               result << Model::Symbol.new( node.name.text, false )
      
            when :spec_reference
               name = node.name.text
               if @specifications.member?(name) then
                  spec = @specifications[name]
                  
                  result = Model::Group.new()
                  case spec.type
                     when :group_spec
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
                        
                     when :rule_spec
                        result << Model::Symbol.new( name, false )
                     when :string_spec
                        result << Model::Symbol.new( name, true )
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
      
      def process_rule_expression( node, naming_context, context_label = nil, is_explicit = false, plural_context = false )
         result = nil
         
         case node.type
            when :macro_call
               result = process_rule_expression( process_macro_call(node), naming_context, context_label, is_explicit, plural_context )
      
            when :sequence_exp
               result = create_sequence( 
                  process_rule_expression( node.tree, naming_context, context_label, is_explicit, plural_context ), 
                  process_rule_expression( node.leaf, naming_context, context_label, is_explicit, plural_context ) 
               )
      
            when :repeated_exp
               minimum = 0
               maximum = nil
               
               case node.repeat_count.text
                  when "?"
                     minimum = 0
                     maximum = 1
                  when "*"
                     minimum = 0
                     maximum = nil
                     plural_context = true
                  when "+"
                     minimum = 1
                     maximum = nil
                     plural_context = true
                  else
                     bug( "unsupported repeat_count [#{node.repeat_count}]")
               end
                  
               result = create_repeater( 
                  process_rule_expression(node.expression, naming_context, context_label, is_explicit, plural_context), minimum, maximum 
               )
               
            when :branch_exp
               result = create_branch_point(
                  process_rule_expression( node.tree, naming_context, context_label, is_explicit, plural_context ),
                  process_rule_expression( node.leaf, naming_context, context_label, is_explicit, plural_context )
               )
               
            when :gateway_exp
               STDERR.puts "skipping gateway_exp, because I've no clue what to do with it"
               result = create_sequence()
               
            when :recovery_commit
               STDERR.puts "skipping recovery_commit, because I've no clue what to do with it"
               result = create_sequence()
            
            when :string_exp
               word_name = anonymous_string( process_string_data(node.string) )
               symbol = Model::Symbol.new( word_name, true )
               result = create_sequence( symbol )
               
               #
               # Strings become slots only if explicitly labelled.
               
               if node.label.exists? and context_label.exists? and is_explicit then
                  nyi( "error handling for overlapping labels" )
               elsif node.label.exists? then
                  naming_context << make_naming_record( symbol, node.label, plural_context, true )
               elsif context_label.exists? and is_explicit then
                  naming_context << make_naming_record( symbol, context_label, plural_context, true )
               end
            
            when :reference_exp
               referenced_name = node.name.text
               if @specifications.member?(referenced_name) then
                  spec = @specifications[referenced_name]
                  
                  if spec.type == :macro_spec then
                     
                     #
                     # Set up for slot naming.  We only supply the macro name as a fallback, if necessary.
               
                     if node.label.exists? and context_label.exists? and is_explicit then
                        nyi( "error handling for overlapping labels" )
                     elsif node.label.exists? then
                        context_label = node.label
                        is_explicit = true
                     elsif context_label.exists? and !is_explicit then
                        context_label = node.name
                     end
               
                     #
                     # Expand the macro and recurse to process.
               
                     result = process_rule_expression( process_macro_call(node), naming_context, context_label, is_explicit, plural_context )
                     
                  else
                     symbol = nil
                     case spec.type
                        when :string_spec
                           symbol = Model::Symbol.new( referenced_name, true )
                        
                        when :rule_spec
                           symbol = Model::Symbol.new( referenced_name, false )
                           
                        when :group_spec
                           symbol = @group_defs[referenced_name].instantiate( referenced_name )
                           
                        else  
                           nyi( "error handling for invalid referenced name [#{referenced_name}]" )
                     end
                           
                     result = create_sequence( symbol )
                  
                     #
                     # All references qualify for slots.  If no explicit label is supplied, we go with the source
                     # name (not anything it might have resolved to).
                  
                     if node.label.exists? and context_label.exists? and is_explicit then
                        nyi( "error handling for overlapping labels" )
                     elsif node.label.exists? then
                        naming_context << make_naming_record( symbol, node.label, plural_context, true )
                     elsif context_label.exists? then
                        naming_context << make_naming_record( symbol, context_label, plural_context, is_explicit )
                     else
                        naming_context << make_naming_record( symbol, node.name, plural_context, false )
                     end
                  end
                  
               else
                  nyi( "error handling for missing referenced name [#{referenced_name}]")
               end
            
            when :group_exp
               if node.label.exists? and context_label.exists? and is_explicit then
                  nyi("error handling for overlapping labels at group level") 
               elsif node.label.exists? then
                  context_label  = node.label
                  is_explicit    = true
               end
               
               result = process_rule_expression( node.expression, naming_context, context_label, is_explicit, plural_context )
               
            when :variable_exp
               nyi( "error handling for variable in regular rule" )
               
            when :transclusion
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
         
         case call_exp.type
            when :reference_exp
               macro_name = call_exp.name.text        # NB: the label is being handled elsewhere!
            when :macro_call
               macro_name = call_exp.macro_name.text
               parameters = call_exp.parameters 
               body       = call_exp.body if call_exp.slot_filled?(:body)
            else
               bug( "why are you passing me a [#{call_exp.type}]?" )
         end
         
         
         nyi( "error handling for undefined macro call [#{macro_name}]" ) unless @specifications.member?(macro_name) 
         nyi( "error handling for bad macro call [#{macro_name}]"       ) unless @specifications[macro_name].type == :macro_spec
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
            case node.type
               when :transclusion
                  nyi( "error handling for missing macro_call body" ) if body.nil?
                  body
               
               when :variable_exp
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
      
      
      
      
      


    #---------------------------------------------------------------------------------------------------------------------
    # Reference support
    #---------------------------------------------------------------------------------------------------------------------

    protected
    
    
      #
      # anonymous_string()
      #  - given a string definition (ExpressionForm of SparseRanges), looks up/registers it under an
      #    anonymous name and returns the name
      
      def anonymous_string( string_def )
         warn_nyi( "anonymous_string() does not presently eliminate duplicates" )
         
         name = "_anonymous" + @string_defs.length.to_s
         @string_defs[name] = string_def
         
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
      #  - returns an ExpressionForms::Repeater
      
      def create_repeater( element, min = 1, max = nil )
         return Util::ExpressionForms::Repeater.new( element, min, max )
      end
      

      #
      # make_naming_record()
      #  - returns a naming record for symbol slot assignment
      
      def make_naming_record( symbol, name_token, context_is_plural, name_is_explicit )
         return [symbol, name_token, context_is_plural, name_is_explicit]
      end
      

      #
      # do_slot_registration()
      #  - given all the necessary information, decides how/if to register a slot or raise an error
      
      def do_slot_registration( symbol, inherited_name, specified_name, naming_context, assign_nil = false )
         name = nil
         
         if inherited_name.exists? and specified_name.exists? then
            nyi( "error handling for overlapping labels ([#{inherited_name.text}] vs [#{specified_name.text}])" ) 
         elsif inherited_name.exists? then
            name = inherited_name
         elsif specified_name.exists? then
            name = specified_name
         elsif !assign_nil then
            set = false
         end
         
         if name then
            naming_context.each do |symbol|
               nyi( "error handling for duplicate labels within rule" ) if symbol.slot_name == name.text
            end
         end
         
         if name or assign_nil then
            symbol.register_slot( name )
            naming_context << symbol
         end
      end
         

      
      
      
    
      
      
   end # ModelBuilder
   


end  # module Grammar
end  # module Languages
end  # module RCC
